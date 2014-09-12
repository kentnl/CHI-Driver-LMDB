use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB::t::CHIDriverTests;

our $VERSION = '0.001000';

# ABSTRACT: Test suite for LMDB driver

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use CHI::Test;
use Path::Tiny;
use parent qw( CHI::t::Driver );

sub testing_driver_class    { 'CHI::Driver::LMDB' }
sub supports_get_namespaces { 0 }

use LMDB_File qw( :all );

my $tempdir = Path::Tiny->tempdir;

if ( $ENV{CHI_KEEP_TEMP_DIR} ) {
  $tempdir->[Path::Tiny::TEMP]->unlink_on_destroy(0);
  warn "Tempdir kept at $tempdir";
}
my $extra_options = {
  mapsize => 15 * 1024 * 1024,
  flags   => MDB_NOSYNC | MDB_NOMETASYNC,
};

sub new_cache_options {
  my $self = shift;
  return (
    root_dir => $tempdir,
    %$extra_options,
    $self->SUPER::new_cache_options()
  );
}

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CHI::Driver::LMDB::t::CHIDriverTests - Test suite for LMDB driver

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
