use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB::t::CHIDriverTests;

# ABSTRACT: Test suite for LMDB driver

# AUTHORITY

use CHI::Test;
use Path::Tiny;
use parent qw( CHI::t::Driver );

sub testing_driver_class { 'CHI::Driver::LMDB' }

use LMDB_File qw( :all );

my $tempdir = Path::Tiny->tempdir;

if ( $ENV{CHI_KEEP_TEMP_DIR} ) {
  $tempdir->[Path::Tiny::TEMP]->unlink_on_destroy(0);
  warn "Tempdir kept at $tempdir";
}
my $extra_options = {};
if ( $ENV{CHI_LMDB_FAST} ) {
  $extra_options->{flags} = MDB_NOSYNC | MDB_NOMETASYNC | MDB_WRITEMAP;
}

sub new_cache_options {
  my $self = shift;
  return (
    root_dir         => $tempdir,
    lmdb_env_options => $extra_options,
    $self->SUPER::new_cache_options()
  );
}

1;

