use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB;

our $VERSION = '0.001000';

# ABSTRACT: use OpenLDAPS LMDB Key-Value store as a cache backend.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Moo qw( extends has );
use Path::Tiny qw( path );
use File::Spec::Functions qw( tmpdir );
use LMDB_File qw( :dbflags :cursor_op );

extends 'CHI::Driver';

has 'dir_create_mode' => ( is => 'ro', default => sub { oct(775) } );

has 'root_dir' => ( is => 'ro', lazy => 1, builder => '_build_root_dir' );

sub _build_root_dir { return path( tmpdir() )->child('chi-driver-lmdb') }

has '_existing_root_dir' => ( is => 'ro', lazy => 1, builder => '_build_existing_root_dir' );

sub _build_existing_root_dir {
  my ($self) = @_;
  my $dir = path( $self->root_dir );
  return $dir if $dir->is_dir;
  $dir->mkpath( { mode => $self->dir_create_mode, } );
  return $dir;
}

has '_existing_namespace_dir' => ( is => 'ro', lazy => 1, builder => '_build_existing_namespace_dir' );

sub _build_existing_namespace_dir {
  my ($self) = @_;
  my $path = path( $self->_existing_root_dir )->child( $self->namespace );
  return $path if $path->is_dir;
  $path->mkpath( { mode => $self->dir_create_mode } );
  return $path;
}

has 'lmdb_env_params' => ( is => 'ro', lazy => 1, builder => '_build_lmdb_env_params' );

sub _build_lmdb_env_params {
  my ($self) = @_;
  return [ $self->_existing_namespace_dir, $self->lmdb_env_options ];
}

has 'lmdb_env_options' => ( is => 'ro', lazy => 1, builder => '_build_lmdb_env_options' );

sub _build_lmdb_env_options {
  my ($self) = @_;
  return {};
}

has '_lmdb_env' => ( is => 'ro', lazy => 1, builder => '_build_lmdb_env' );

sub _build_lmdb_env {
  my ($self) = @_;
  return LMDB::Env->new( @{ $self->lmdb_env_params } );
}

has '_lmdb_txn' => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_lmdb_txn',
  clearer => '_clear_lmdb_txn',
);

sub _build_lmdb_txn {
  my ($self) = @_;
  my $tx = $self->_lmdb_env->BeginTxn();
  $tx->AutoCommit(1);
  return $tx;
}

has '_lmdb_db' => (
  is      => 'ro',
  lazy    => 1,
  builder => '_build_lmdb_db',
  clearer => '_clear_lmdb_db',
);

sub _build_lmdb_db {
  my ($self) = @_;
  $self->_lmdb_txn->OpenDB( { flags => MDB_CREATE, } );
}

sub store {
  my ( $self, $key, $data ) = @_;
  $self->_lmdb_db->put( $key, $data );
}

sub fetch {
  my ( $self, $key ) = @_;
  $self->_lmdb_db->get($key);
}

sub remove {
  my ( $self, $key ) = @_;
  $self->_lmdb_db->del( $key, undef );
}

sub clear {
  my ($self) = @_;
  my $db = $self->_lmdb_db;
  for my $key ( $self->get_keys ) {
    $db->del( $key, undef );
  }
}

sub get_keys {
  my ($self) = @_;
  my $db     = $self->_lmdb_db;
  my $cursor = $db->Cursor;
  my @keys;
  my ( $key, $value );
  while (1) {
    last unless eval { $cursor->get( $key, $value, MDB_NEXT ); 1 };
    push @keys, $key;
  }
  return @keys;
}

sub get_namespaces {
  my ($self) = @_;
  my @out;
  for my $child ( path( $self->_existing_root_dir )->children ) {
    next unless $child->is_dir;
    push @out, $child->basename;
  }
  return @out;
}

around max_key_length => sub {
  my ( $orig, $self, @args ) = @_;
  my $rval     = $self->$orig(@args);
  my $real_max = $self->_lmdb_env->get_maxkeysize;
  return $rval > $real_max ? $real_max : $rval;
};

no Moo;

1;

__END__

=pod

=encoding UTF-8

=head1 NAME

CHI::Driver::LMDB - use OpenLDAPS LMDB Key-Value store as a cache backend.

=head1 VERSION

version 0.001000

=head1 AUTHOR

Kent Fredric <kentnl@cpan.org>

=head1 COPYRIGHT AND LICENSE

This software is copyright (c) 2014 by Kent Fredric <kentfredric@gmail.com>.

This is free software; you can redistribute it and/or modify it under
the same terms as the Perl 5 programming language system itself.

=cut
