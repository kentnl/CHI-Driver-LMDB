use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB;

our $VERSION = '0.001000';

# ABSTRACT: use OpenLDAPS LMDB Key-Value store as a cache backend.

our $AUTHORITY = 'cpan:KENTNL'; # AUTHORITY

use Carp qw( croak );
use Moo qw( extends has );
use Path::Tiny qw( path );
use File::Spec::Functions qw( tmpdir );
use LMDB_File qw( MDB_CREATE MDB_NEXT );
extends 'CHI::Driver';

has 'dir_create_mode' => ( is => 'ro', lazy => 1, default => oct(775) );
has 'root_dir'        => ( is => 'ro', lazy => 1, builder => '_build_root_dir' );
has 'cache_size'      => ( is => 'ro', lazy => 1, default => '5m' );
has 'single_txn'      => ( is => 'ro', lazy => 1, default => sub { undef } );
has 'db_flags'        => ( is => 'ro', lazy => 1, default => MDB_CREATE );
has 'tx_flags'        => ( is => 'ro', lazy => 1, default => 0 );
has 'put_flags'       => ( is => 'ro', lazy => 1, default => 0 );

my %env_opts = (
  mapsize => { is => 'ro', lazy => 1, builder => '_build_mapsize' },

  # TODO: Uncomment this line when https://rt.cpan.org/Public/Bug/Display.html?id=98821 is solved.
  #   maxreaders => { is => 'ro', lazy => 1, default => 126 },
  maxdbs => { is => 'ro', lazy => 1, default => 1024 },
  mode   => { is => 'ro', lazy => 1, default => oct(600) },
  flags  => { is => 'ro', lazy => 1, default => 0 },
);

for my $attr ( keys %env_opts ) {
  has $attr => %{ $env_opts{$attr} };
}

sub _build_root_dir {
  return path( tmpdir() )->child( 'chi-driver-lmdb-' . $> );
}

has '_existing_root_dir' => ( is => 'ro', lazy => 1, builder => '_build_existing_root_dir' );

sub _build_existing_root_dir {
  my ($self) = @_;
  my $dir = path( $self->root_dir );
  return $dir if $dir->is_dir;
  $dir->mkpath( { mode => $self->dir_create_mode, } );
  return $dir;
}

has '_lmdb_env'     => ( is => 'ro', builder => '_build_lmdb_env',     lazy => 1, );
has '_lmdb_max_key' => ( is => 'ro', builder => '_build_lmdb_max_key', lazy => 1 );

sub _build_lmdb_env {
  my ($self) = @_;
  return LMDB::Env->new( $self->_existing_root_dir . q[], { map { $_ => $self->$_() } keys %{$env_opts} } );
}

sub _build_lmdb_max_key {
  my ($self) = @_;
  return $self->_lmdb_env->get_maxkeysize;
}

sub BUILD {
  my ($self) = @_;
  if ( $self->single_txn ) {
    $self->{in_txn} = $self->_mk_txn;
  }
  return;
}

sub DEMOLISH {
  my ($self) = @_;
  if ( $self->{in_txn} ) {
    $self->{in_txn}->[0]->commit;
    delete $self->{in_txn};
  }
  return;
}

sub _mk_txn {
  my ($self) = @_;

  # TODO: Use slightly more natural ->OpenDB
  # https://rt.cpan.org/Public/Bug/Display.html?id=98681
  my $tx = $self->_lmdb_env->BeginTxn();
  $tx->AutoCommit(1);
  my $db = LMDB_File->open( $tx, $self->namespace, $self->db_flags );
  return [ $tx, $db ];
}

sub _in_txn {
  my ( $self, $cb ) = @_;
  if ( $self->{in_txn} ) {
    return $cb->( @{ $self->{in_txn} } );
  }
  local $self->{in_txn} = $self->_mk_txn;
  my $rval = $cb->( @{ $self->{in_txn} } );
  $self->{in_txn}->[0]->commit;
  return $rval;
}

sub store {
  my ( $self, $key, $data ) = @_;
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      $db->put( $key, $data, $self->put_flags );
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

  # TODO: Eliminate need for undef
  # https://rt.cpan.org/Public/Bug/Display.html?id=98671
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      $db->del( $key, undef );
    }
  );
}

sub clear {
  my ($self) = @_;

  # TODO: Implement in mdb_drop https://rt.cpan.org/Public/Bug/Display.html?id=98682
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      for my $key ( $self->get_keys ) {
        $db->del( $key, undef );
      }
    }
  );
}

sub fetch_multi_hashref {
  my ( $self, $keys ) = @_;
  my $out = {};
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      for my $key ( @{$keys} ) {
        $out->{$key} = $db->get($key);
      }
    }
  );
  return $out;
}

sub store_multi {
  my ( $self, $key_data, $options ) = @_;
  croak "must specify key_values" unless defined($key_data);
  $self->_in_txn(
    sub {
      my ( $tx, $db ) = @_;
      for my $key ( keys %{$key_data} ) {
        $self->set( $key, $key_data->{$key} );
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

sub get_namespaces { croak 'not supported' }

around max_key_length => sub {
  my ( $orig, $self, @args ) = @_;
  my $rval     = $self->$orig(@args);
  my $real_max = $self->_lmdb_max_key;
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
