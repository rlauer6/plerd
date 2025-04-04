use warnings;
use strict;
use Test::More;
use Path::Class::Dir;
use Path::Class::File;
use Capture::Tiny ':all';
use File::ShareDir qw(dist_dir);
use English qw(-no_match_vars);

use FindBin;
use lib "$FindBin::Bin/../lib";

my $plerdall = "$FindBin::Bin/../bin/plerdall";

my $dist_dir = dist_dir('Plerd');

my $init_dir = Path::Class::Dir->new("$FindBin::Bin/init");
$init_dir->rmtree;
$init_dir->mkpath;

chdir $init_dir or die "Can't chdir to $init_dir: $!";

# Write out a (blank) config file for this test.
my $config_file_path = Path::Class::File->new( $FindBin::Bin, 'test.conf', );

$config_file_path->spew('');

# Run init at the default location.
{
  run_init();
  check_wrapper('plerd');
}

# Run init at a specified location.
{
  run_init('foobar');
  check_wrapper('foobar');
}

done_testing;

########################################################################
sub run_init {
########################################################################
  my ($init_target) = @_;

  my $init_arg = '--init';

  if ( defined $init_target ) {
    $init_arg .= "=$init_target";
  }

  # Capture these, even though we don't do anything with them (yet)
  my ( $stdout, $stderr, $exit ) = capture {

    my $cmd = sprintf '%s -I %s/../lib/ %s %s --config=%s', $EXECUTABLE_NAME, $FindBin::Bin, $plerdall, $init_arg;

    system $cmd;
  };

  return;
}

# check_wrapper: Just check for the existence of templates/wrapper.tt,
#                and make sure it seems to have expected content.
########################################################################
sub check_wrapper {
########################################################################

  my ($subdir) = @_;

  my $wrapper = Path::Class::File->new( $init_dir, $subdir, 'templates', 'wrapper.tt' );

  ok( -e $wrapper, "Wrapper template exists under '$subdir'." );

  my $wrapper_content = $wrapper->slurp;

  like( $wrapper_content, qr{<h1>Hello</h1>}xsm, 'Wrapper content looks okay.', );

  return;
}

1;
