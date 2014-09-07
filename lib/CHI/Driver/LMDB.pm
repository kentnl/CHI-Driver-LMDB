use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB;

our $VERSION = '0.001000';

# ABSTRACT: use OpenLDAPS LMDB Key-Value store as a cache backend.

# AUTHORITY

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

sub _in_txn {
  my ( $self, $cb ) = @_;
  my $tx = $self->_lmdb_env->BeginTxn();
  $tx->AutoCommit(1);
  my $db = $tx->OpenDB( { flags => MDB_CREATE } );
  my $rval = $cb->( $tx, $db );
  $tx->commit;
  return $rval;
}

sub store {
  my ( $self, $key, $data ) = @_;
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      $db->put( $key, $data );
    }
  );
}

sub fetch {
  my ( $self, $key ) = @_;
  my $rval;
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      $rval = $db->get($key);
    }
  );
  return $rval;
}

sub remove {
  my ( $self, $key ) = @_;
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      $db->del( $key, undef );
    }
  );
}

sub clear {
  my ($self) = @_;

  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      for my $key ( $self->get_keys ) {
        $db->del( $key, undef );
      }
    }
  );
}

sub get_keys {
  my ($self) = @_;
  my @keys;

  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      my $cursor = $db->Cursor;
      my ( $key, $value );
      while (1) {
        last unless eval { $cursor->get( $key, $value, MDB_NEXT ); 1 };
        push @keys, $key;
      }
    }
  );
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
