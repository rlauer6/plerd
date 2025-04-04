package Plerd::Post;

use Data::Dumper;
use Data::GUID;
use DateTime::Format::W3CDTF;
use DateTime;
use HTML::SocialMeta;
use HTML::Strip;
use JSON;
use List::Util qw(none);
use Moose;
use Path::Class::File;
use Plerd::SmartyPants;
use Text::Markdown::Discount qw(markdown);
use Try::Tiny;
use URI;
use Web::Mention;
use Readonly;

Readonly my $WPM => 200;  # The words-per-minute reading speed to assume

Readonly my $TRUE  => 1;
Readonly my $FALSE => 0;
Readonly my $EMPTY => q{};

has 'plerd' => (
  is       => 'ro',
  required => 1,
  isa      => 'Plerd',
  weak_ref => $TRUE,
);

has 'source_file' => (
  is       => 'ro',
  isa      => 'Path::Class::File',
  required => $TRUE,
  trigger  => \&_process_source_file,
);

has 'publication_file' => (
  is         => 'ro',
  isa        => 'Path::Class::File',
  lazy_build => $TRUE,
);

has 'title' => (
  is  => 'rw',
  isa => 'Str',
);

has 'body' => (
  is  => 'rw',
  isa => 'Str',
);

has 'stripped_body' => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'stripped_title' => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'attributes' => (
  is  => 'rw',
  isa => 'HashRef',
);

has 'tag_objects' => (
  is      => 'rw',
  isa     => 'ArrayRef',
  default => sub { [] },
);

has 'image' => (
  is      => 'rw',
  isa     => 'Maybe[URI]',
  default => undef,
);

has 'image_alt' => (
  is      => 'rw',
  isa     => 'Maybe[Str]',
  default => undef,
);

has 'description' => (
  is      => 'rw',
  isa     => 'Str',
  default => $EMPTY,
);

has 'date' => (
  is      => 'rw',
  isa     => 'DateTime',
  handles => [
    qw(
      month
      month_name
      day
      year
      ymd
      hms
    )
  ],
  trigger => \&_build_utc_date,
);

has 'utc_date' => (
  is         => 'rw',
  isa        => 'DateTime',
  lazy_build => $TRUE,
);

has 'published_filename' => (
  is         => 'rw',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'uri' => (
  is         => 'ro',
  isa        => 'URI',
  lazy_build => $TRUE,
);

has 'relative_uri' => (
  is         => 'ro',
  isa        => 'URI',
  lazy_build => $TRUE,
);

has 'guid' => (
  is  => 'rw',
  isa => 'Data::GUID',
);

has 'updated_timestamp' => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'published_timestamp' => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'newer_post' => (
  is         => 'ro',
  isa        => 'Maybe[Plerd::Post]',
  lazy_build => $TRUE,
);

has 'older_post' => (
  is         => 'ro',
  isa        => 'Maybe[Plerd::Post]',
  lazy_build => $TRUE,
);

has 'reading_time' => (
  is         => 'ro',
  isa        => 'Num',
  lazy_build => $TRUE,
);

has 'socialmeta' => (
  is         => 'ro',
  isa        => 'Maybe[HTML::SocialMeta]',
  lazy_build => $TRUE,
);

has 'social_meta_tags' => (
  is         => 'ro',
  isa        => 'Str',
  lazy_build => $TRUE,
);

has 'socialmeta_mode' => (
  is      => 'rw',
  isa     => 'Str',
  default => 'summary',
);

sub _build_publication_file {
  my $self = shift;

  return Path::Class::File->new( $self->plerd->publication_directory, $self->published_filename, );
}

sub _build_published_filename {
  my $self = shift;

  my $filename = $self->source_file->basename;

  # If the source filename already seems Plerdish, just replace its extension.
  # Else, generate a Plerdish filename based on the post's date and title.
  if ( $filename =~ /^(\d{4})-(\d{2})-(\d{2})/xsm ) {
    $filename =~ s/[.].*$/.html/xsm;
  }
  else {
    $filename = $self->title;
    my $stripper = HTML::Strip->new( emit_spaces => 0 );
    $filename = $stripper->parse($filename);
    $filename =~ s/\s+/-/xsmg;
    $filename =~ s/--+/-/xsmg;
    $filename =~ s/[^\w\-]+//xsmg;
    $filename = lc $filename;
    $filename = $self->date->ymd(q{-}) . q{-} . $filename;
    $filename .= '.html';
  }

  return $filename;
}

sub _build_relative_uri {
  my $self = shift;

  my $base_uri .= q{/};

  return URI->new_abs( $self->published_filename, $base_uri, );
}

sub _build_uri {
  my $self = shift;

  my $base_uri = $self->plerd->base_uri;
  if ( $base_uri =~ /[^\/]$/xsm ) {
    $base_uri .= q{/};
  }
  return URI->new_abs( $self->published_filename, $base_uri, );
}

sub _build_updated_timestamp {
  my $self = shift;

  my $mtime = $self->source_file->stat->mtime;

  my $formatter = DateTime::Format::W3CDTF->new;
  my $timestamp = $formatter->format_datetime(
    DateTime->from_epoch(
      epoch     => $mtime,
      time_zone => 'local',
    ),
  );

  return $timestamp;
}

sub _build_newer_post {
  my $self = shift;

  my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

  my $newer_post;
  if ( $index - 1 >= 0 ) {
    $newer_post = $self->plerd->posts->[ $index - 1 ];
  }

  return $newer_post;
}

sub _build_older_post {
  my $self = shift;

  my $index = $self->plerd->index_of_post_with_guid->{ $self->guid };

  my $older_post = $self->plerd->posts->[ $index + 1 ];

  return $older_post;
}

sub _build_published_timestamp {
  my $self = shift;

  my $formatter = DateTime::Format::W3CDTF->new;
  my $timestamp = $formatter->format_datetime( $self->date );

  return $timestamp;
}

sub _build_guid {
  my $self = shift;

  return Data::GUID->new;
}

sub _build_reading_time {
  my $self = shift;

  my @words = $self->stripped_body =~ /(\w+)\W*/xsmg;

  return int( scalar(@words) / $WPM ) + 1;
}

sub _build_stripped_body {
  my $self = shift;

  return $self->_strip_html( $self->body );
}

sub _build_stripped_title {
  my $self = shift;

  return $self->_strip_html( $self->title );
}

sub _strip_html {
  my ( $self, $raw_text ) = @_;

  my $stripped = HTML::Strip->new->parse($raw_text);

  # Clean up apparently orphaned punctuation
  $stripped =~ s{ ([;.,?!])}{$1}xsmg;

  return $stripped;
}

sub _build_socialmeta {
  my $self = shift;

  if ( !$self->image ) {
    # Neither this post nor this whole blog defines an image URL.
    # So, no social meta-tags for this post.
    return;
  }

  my %args = (
    site_name   => $self->plerd->title,
    title       => $self->title,
    description => $self->description,
    image       => $self->image->as_string,
    url         => $self->uri->as_string,
    fb_app_id   => $self->plerd->facebook_id || $EMPTY,
    site        => $self->plerd->twitter_id  || $EMPTY,
    image_alt   => $self->image_alt,
  );

  if ( $args{site} ) {
    $args{site} = q{@} . $args{site};
  }

  my $socialmeta;

  try {
    $socialmeta = HTML::SocialMeta->new(%args);
  }
  catch {
    warn sprintf "Couldn't build an HTML::SocialMeta object for post %s:%s\n", $self->source_file->basename, $_;
  };

  return $socialmeta;
}

sub _build_social_meta_tags {
  my $self = shift;

  my $tags = $EMPTY;

  my %targets = (
    twitter   => 'twitter_id',
    opengraph => 'facebook_id',
  );

  if ( $self->socialmeta ) {
    for my $target ( keys %targets ) {
      my $id_method = $targets{$target};
      if ( $self->plerd->$id_method ) {
        try {
          $tags .= $self->socialmeta->$target->create( $self->socialmeta_mode );
        }
        catch {
          warn "Couldn't create $target meta tags for " . $self->source_file->basename . ": $_\n";
        };
      }
    }
  }

  return $tags;

}

# This next internal method does a bunch of stuff.
# It's called via Moose-trigger when the object's source_file attribute is set.
# * Read and store the file's data (body) and metadata
# * Figure out the publication timestamp, based on possible (not guaranteed!)
#   presence of date in the filename AND/OR "time" metadata attribute
# * If the file lacks a various required attributes, rewrite the file so that
#   it has them.
sub _process_source_file {
  my $self = shift;

  # Slurp the file, storing the title and time metadata, and the body.
  my $fh = $self->source_file->open('<:encoding(utf8)');
  my %attributes;
  my @ordered_attribute_names = qw( title time published_filename guid tags);

  while ( my $line = <$fh> ) {
    chomp $line;
    last if $line !~ /\S/xsm;

    my ( $key, $value ) = $line =~ /^\s*(\w+?)\s*:\s*(.*?)\s*$/xsm;

    if ($key) {
      $key = lc $key;
      $attributes{$key} = $value;

      if ( none { $_ eq $key } @ordered_attribute_names ) {
        push @ordered_attribute_names, $key;
      }
    }
  }

  $self->attributes( \%attributes );

  my $body;

  while (<$fh>) {
    $body .= $_;
  }

  close $fh;

  if ( $attributes{title} ) {
    $self->title( $attributes{title} );
  }
  else {
    die sprintf 'Error processing %s: File content does not define a post title.', $self->source_file;
  }

  $self->body($body);

  foreach (qw( title body )) {
    if ( defined( $self->$_ ) ) {
      $self->$_( Plerd::SmartyPants::process( markdown( $self->$_ ) ) );
    }
  }

  # Strip unnecessary <p> tags that the markdown processor just added to the title.
  my $stripped_title = $self->title;
  $stripped_title =~ s{</?p>\s*}{}xsmg;
  $self->title($stripped_title);

  # Check and tune attributes used to render social-media metatags.
  if ( $attributes{description} ) {
    $self->description( $attributes{description} );
  }
  else {
    my $body = $self->stripped_body;
    my ($description) = $body =~ /^\s*(.*)\n/xsm;
    $self->description( $description || $EMPTY );
  }

  if ( $attributes{image} ) {
    $self->image( URI->new( $attributes{image} ) );
    $self->image_alt( $attributes{image_alt} || $EMPTY );
    $self->socialmeta_mode('featured_image');
  }
  else {
    $attributes{image_style} //= $self->plerd->image_style // q{};

    $self->image( $self->plerd->image );
    $self->image_alt( $self->plerd->image_alt || $EMPTY );
  }

  # Note whether the filename asserts the post's publication date.
  my ( $filename_year, $filename_month, $filename_day ) = $self->source_file->basename =~ /^(\d{4})-(\d{2})-(\d{2})/xsm;

  # Set the post's date, using these rules:
  # * If the post has a time attribute in W3 format, use that
  # * Elsif the post's filename asserts a date, use midnight of that date,
  #   and also add a time attribute to the file.
  # * Else use right now, and also add a time attribute to the file.
  my $attributes_need_to_be_written_out = $FALSE;

  if ( $attributes{time} ) {
    eval {
      $self->date( $self->plerd->datetime_formatter->parse_datetime( $attributes{time} ) );
      $self->date->set_time_zone('local');
    };

    die sprintf 'Error processing %s: The "time" attribute is not in W3C format.', $self->source_file
      if !$self->date;
  }
  else {
    my $publication_dt;

    if ($filename_year) {
      # The post specifies its day in the filename, but we still don't have a
      # publication hour.
      # If the filename's date is today (locally), use the current time.
      # Otherwise, use midnight of the provided date.
      my $now = DateTime->now( time_zone => 'local' );

      my $ymd = $now->ymd(q{-});

      if ( $self->source_file->basename =~ /^$ymd/xsm ) {
        $publication_dt = $now;
      }
      else {
        $publication_dt = DateTime->new(
          year      => $filename_year,
          month     => $filename_month,
          day       => $filename_day,
          time_zone => 'local',
        );
      }
    }
    else {
      # The file doesn't name the time, *and* the file doesn't contain the date
      # in metadata (or else we wouldn't be here), so we'll just use right-now.
      $publication_dt = DateTime->now( time_zone => 'local' );
    }

    $self->date($publication_dt);

    my $date_string = $self->plerd->datetime_formatter->format_datetime($publication_dt);

    $attributes{time} = $date_string;
    $attributes_need_to_be_written_out = $TRUE;
  }

  if ( $attributes{published_filename} ) {
    $self->published_filename( $attributes{published_filename} );
  }
  else {
    $attributes{published_filename} = $self->published_filename;
    $attributes_need_to_be_written_out = $TRUE;
  }

  if ( $attributes{guid} ) {
    $self->guid( Data::GUID->from_string( $attributes{guid} ) );
  }
  else {
    $attributes{guid} = Data::GUID->new;
    $self->guid( $attributes{guid} );
    $attributes_need_to_be_written_out = $TRUE;
  }

  if ( $attributes{tags} ) {
    my @tag_names = split /\s*,\s*/xsm, $attributes{tags};

    for my $tag_name (@tag_names) {
      my $tag = $self->plerd->tag_named($tag_name);
      $tag->add_post($self);
      push @{ $self->tag_objects }, $tag;
    }
  }

  if ($attributes_need_to_be_written_out) {
    my $new_content = $EMPTY;

    for my $attribute_name (@ordered_attribute_names) {
      if ( defined $attributes{$attribute_name} ) {
        $new_content .= "$attribute_name: $attributes{ $attribute_name }\n";
      }
    }
    $new_content .= "\n$body\n";
    $self->source_file->spew( iomode => '>:encoding(utf8)', $new_content );
  }

  return;
}

sub publish {
  my $self = shift;

  # Make <title>-ready text free of possible Markdown-generated HTML tags.
  my $stripped_title = $self->title;
  $stripped_title =~ s{</?(em|strong)>}{}xsmg;

  my $html_fh     = $self->publication_file->openw;
  my $template_fh = $self->plerd->post_template_file->openr;
  foreach ( $html_fh, $template_fh ) {
    $_->binmode(':utf8');
  }

  return $self->plerd->template->process(
    $template_fh,
    { plerd        => $self->plerd,
      posts        => [$self],
      title        => $stripped_title,
      context_post => $self,
    },
    $html_fh,
  ) || $self->plerd->_throw_template_exception( $self->plerd->post_template_file );
}

sub send_webmentions {
  my $self = shift;

  my @wms = Web::Mention->new_from_html(
    source => $self->uri,
    html   => $self->body,
  );

  my %report = (
    attempts  => 0,
    delivered => 0,
    sent      => 0,
  );
  foreach (@wms) {
    $report{attempts}++;
    if ( $_->send ) {
      $report{delivered}++;
    }
    if ( $_->endpoint ) {
      $report{sent}++;
    }
  }

  return ( \%report );
}

sub _build_utc_date {
  my $self = shift;

  my $dt = $self->date->clone;
  $dt->set_time_zone('UTC');
  return $dt;
}

sub tags {
  my $self = shift;

  return [ map { $_->name } @{ $self->tag_objects } ];
}

1;

__END__

=pod

=head1 NAME

Plerd::Post - A Plerd blog post

=head1 SYNOPSIS

 use Plerd::Post;

 my $post = Plerd::Post->new;


=head1 DESCRIPTION

An object of the class Plerd::Post represents a single post to a
Plerd-based blog, with Markdown source and HTML output.

=head1 METHODS AND SUBROUTINES

=over

=item new( \%config )

Object constructor. The single config hashref I<must> include the
following keys:

=over

=item plerd

The parent Plerd object.

=item source_file

A Path::Class::File object representing this post's Markdown source
file.

=back

=back

=head1 OBJECT ATTRIBUTES

=head2 Read-only attributes

=over

=item newer_post

A Plerd::Post object representing the next-newer post to the blog.

Is the current object represents the newest post in the blog, then this
method returns undef.

=item older_post

A Plerd::Post object representing the next-older post to the blog.

Is the current object represents the oldest post in the blog, then this
method returns undef.

=item published_filename

The local filename (without parent directory path) of the HTML file that
this post will generate upon publication.

=item published_timestamp

This post's date, in W3C format, set to midnight in the local timezone.

=item reading_time

An estimated reading-time for this post, measured in whole minutes, and
based on an assumed (and fairly conservative) reading pace of 200 words
per minute.

=item updated_timestamp

The modification time of this this post's source file, in W3C format,
set to the local timezone.

=item uri

The L<URI> of the of the HTML file that this post will generate upon
publication.

=item utc_date

Returns the value of C<date> (see below), with the time zone set to UTC.

=back

=head2 Read-write attributes

=over

=item attributes

A hashref of all the attributes defined in the source document's
metadata section, whether or not Plerd takes any special meaning from
them.

For example, if a source document defines both C<title> and
C<favorite_color> key-value pairs in its metadata, both keys and values
will appear in this hashref, even though Plerd pays no mind to the
latter key.

=item body

String representing the post's body text.

=item date

L<DateTime> object representing this post's presented publication date.

Plerd usually sets this for you, based on the post's metadata, and sets
the time zone to local. If you'd like the object in UTC time instead,
use the C<utc_date> attribute.

=item description

String representing a short, descriptive summary of this post. This
value affects the metadata attached to this post, for use by social
media and such.

If you don't set this value yourself by the time Plerd needs it, then it
will set it to the first paragraph of the post's body text (with all
markup removed).

=item image

(Optional) L<URI> object referencing an illustrative image for this
post.

Setting this value affects the metadata attached to this post, for use
by social media and such.

=item image_alt

(Optional) A text description of the image referenced by the C<image>
atribute.

Setting this value affects the metadata attached to this post, for use
by social media and such.

=item title

String representing this post's title.

=item tags

An array reference to the list of tags (as plain-text strings)
associated with this post as set in the source file using the 'tags:'
header.

=item tag_objects

An array reference to the list of tags (as L<Plerd::Tag> objects)
associated with this post as set in the source file using the 'tags:'
header.

=back

=head1 OBJECT METHODS

=head2 publish

 $post->publish

Publishes the post.

=head2 send_webmentions

 $report = $post->send_webmentions

Attempts to send a webmention for every hyperlink contained in the post.

The return value is a hashref with the following keys:

=over

=item attempts

The number of webmentions this post attempted to send.

=item sent

The number of webmentions actually sent (due to webmention-endpoint URLs
advertised by the links' targets).

=item delivered

The number of webmentions whose delivery was acknowledged by the
receiving endpoint.

=back

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>

=cut
