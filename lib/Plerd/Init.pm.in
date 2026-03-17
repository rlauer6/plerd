package Plerd::Init;

use strict;
use warnings;

use utf8;

use Cwd qw(realpath);
use Data::Dumper;
use English qw(-no_match_vars);
use File::Copy;
use File::Path qw(make_path);
use File::ShareDir qw(dist_dir);
use Plerd;

########################################################################
sub initialize {
########################################################################
  my ($init_path) = @_;

  $init_path //= q{};

  my @messages;

  my $dir = realpath $init_path;

  if ( !$init_path ) {
    push @messages, "No directory provided, so using default location ($dir).\n";
  }

  return [ @messages, "$dir exists, but it's not a directory!\nExiting." ]
    if -e $dir && !-d $dir;

  my $success = populate_directory( $dir, \@messages );

  if ($success) {
    my $config_file = "$dir/plerd.com";

    push @messages,
        'I have created and populated a new Plerd working directory at '
      . "$dir. Your next step involves updating the configuration file "
      . "at $config_file.\n"
      . 'For full documentation, links to mailing lists, and other stuff, '
      . 'please visit http://plerd.jmac.org/. Enjoy!';
  }

  return \@messages;
}

########################################################################
sub populate_directory {
########################################################################
  my ( $dir, $messages ) = @_;

  print {*STDERR} "initializing $dir\n";

  my $dist_dir      = dist_dir('Plerd');
  my $file_template = '%s/%s.tt';

  if ( -d $dir ) {
    make_path( $dir, { chmod => 0777 } );
  }

  eval {
    make_path( ( map { sprintf '%s/%s', $dir, $_ } qw( docroot source templates log run db conf ) ), { chmod => 0777 } );

    foreach (qw( archive atom jsonfeed post wrapper tags )) {
      my $src = sprintf $file_template, $dist_dir, $_;

      my $dest = sprintf $file_template, "$dir/templates", $_;
      copy( $src, $dest );
    }
  };

  return
    if !$EVAL_ERROR;

  push @{$messages}, $EVAL_ERROR;

  push @{$messages},
      "I am cowardly declining to clean up $dir. You might "
    . 'need to empty or remove it yourself before trying '
    . 'this command again.';

  push @{$messages}, 'Exiting.';

  return 0;
}

1;

__END__

=pod

=head1 NAME

Plerd::Init

=head1 DESCRIPTION

This module just defines a bunch of utility classes used by plerdall's
"init" verb. It offers no public API.

=head1 SEE ALSO

Plerd

=head1 AUTHOR

Jason McIntosh <jmac@jmac.org>

=cut
