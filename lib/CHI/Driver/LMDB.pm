use 5.008;    # utf8
use strict;
use warnings;
use utf8;

package CHI::Driver::LMDB;

our $VERSION = '0.002000';

# ABSTRACT: use OpenLDAPs LMDB Key-Value store as a cache backend.

# AUTHORITY

use Carp qw( croak );
use Moo qw( extends has around );
use Path::Tiny qw( path );
use File::Spec::Functions qw( tmpdir );
use LMDB_File 0.006 qw( MDB_CREATE MDB_NEXT );
extends 'CHI::Driver';

has 'dir_create_mode' => ( is => 'ro', lazy => 1, default => oct 775 );
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
  mode   => { is => 'ro', lazy => 1, default => oct 600 },
  flags  => { is => 'ro', lazy => 1, default => 0 },
);

for my $attr ( keys %env_opts ) {
  has $attr => %{ $env_opts{$attr} };
}

my $sizes = {
  k => 1024,
  m => 1024 * 1024,
};

sub _build_mapsize {
  my ($self) = @_;
  my $cache_size = $self->cache_size;
  if ( $cache_size =~ s/([km])\z//msxi ) {
    $cache_size *= $sizes->{ lc $1 };
  }
  return $cache_size;
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
  return LMDB::Env->new( $self->_existing_root_dir . q[], { map { $_ => $self->$_() } keys %env_opts } );
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

  my $tx = $self->_lmdb_env->BeginTxn();
  $tx->AutoCommit(1);
  my $db = $tx->OpenDB( { dbname => $self->namespace, flags => $self->db_flags } );
  return [ $tx, $db ];
}

sub _in_txn {
  my ( $self, $cb ) = @_;
  if ( $self->{in_txn} ) {
    return $cb->( @{ $self->{in_txn} } );
  }
  ## no critic (Variables::ProhibitLocalVars)
  local $self->{in_txn} = $self->_mk_txn;
  my $rval = $cb->( @{ $self->{in_txn} } );
  $self->{in_txn}->[0]->commit;
  return $rval;
}

sub store {
  my ( $self, $key, $value ) = @_;
  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      $db->put( $key, $value, $self->put_flags );
    },
  );
  return $self;
}

sub fetch {
  my ( $self, $key ) = @_;
  my $rval;
  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      $rval = $db->get($key);
    },
  );
  return $rval;
}

sub remove {
  my ( $self, $key ) = @_;

  # TODO: Eliminate need for undef
  # https://rt.cpan.org/Public/Bug/Display.html?id=98671
  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      $db->del( $key, undef );
    },
  );
  return;
}

sub clear {
  my ($self) = @_;

  # TODO: Implement in mdb_drop https://rt.cpan.org/Public/Bug/Display.html?id=98682
  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      for my $key ( $self->get_keys ) {
        $db->del( $key, undef );
      }
    },
  );
  return;
}

sub fetch_multi_hashref {
  my ( $self, $keys ) = @_;
  my $out = {};
  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      for my $key ( @{$keys} ) {
        $out->{$key} = $db->get($key);
      }
    },
  );
  return $out;
}

sub store_multi {
  my ( $self, $key_data, $set_options ) = @_;
  croak 'must specify key_values' unless defined $key_data;
  $self->_in_txn(
    sub {
      for my $key ( keys %{$key_data} ) {
        $self->set( $key, $key_data->{$key}, $set_options );
      }
    },
  );
  return;
}

sub get_keys {
  my ($self) = @_;
  my @keys;

  $self->_in_txn(
    sub {
      my ( undef, $db ) = @_;
      my $cursor = $db->Cursor;
      my ( $key, $value );
      while (1) {
        last unless eval { $cursor->get( $key, $value, MDB_NEXT ); 1 };
        push @keys, $key;
      }
      return;
    },
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

=head1 SYNOPSIS

  use CHI;

  my $cache = CHI->new(
    driver => 'LMDB',
    root_dir => 'some/path',
    namespace => "My::Project",
  );

See L<C<CHI> documentation|CHI> for more details on usage.

=attr C<dir_create_mode>

What mode (if any) to use when creating C<root_dir> if it does not exist.

  ->new(
    # Default is 775 = rwxr-xr-x
    dir_create_mode => oct 666,
  );

=attr C<root_dir>

The prefix directory the C<LMDB> data store will be installed to.

  ->new(
    root_dir => 'some/path'
  )

Default is:

  OSTEMPDIR/chi-driver-lmdb-$EUID

=attr C<cache_size>

The size in bytes for each database.

This is a convenience wrapper for L</mapsize> which supports suffixes:

  cache_size => 5  # 5 bytes
  cache_size => 5k # 5 Kilobytes
  cache_size => 5m # 5 Megabytes ( default )

This is also designed for syntax compatibility with L<< C<CHI::Driver::FastMmap>|CHI::Driver::FastMmap >>

=attr C<single_txn>

  single_txn => 1

B<SPEED>: For performance benefits, have a single transaction
that lives from the creation of the CHI cache till its destruction.

However, B<WARNING:> this flag is currently a bit dodgy, and CHI caches being kept alive
till global destruction B<WILL> trigger a C<SEGV>, and potentially leave your cache broken.

You can avoid this by manually destroying the cache with:

  undef $cache

Prior to global destruction.

=attr C<db_flags>

Flags to pass to C<OpenDB>/C<< LMDB_File->open >>.

See L<< C<LMDB_File>'s constructor options|LMDB_File/LMDB_File >> for details.

  use LMDB_File qw( MDB_CREATE );

  db_flags => MDB_CREATE # default

=attr C<tx_flags>

Flags to pass to C<< LMDB::Env->new >>

See L<< C<LMDB::Env>'s constructor options|LMDB_File/LMDB::Env >> for details.

Default is C<0>

  tx_flags => 0 # no flags

=attr C<put_flags>

Flags to pass to C<< ->put(k,v,WRITE_FLAGS) >>.

See L<< LMDB_File->put options|LMDB_File/LMDB_File >> for details.

=attr C<mapsize>

Passes through to C<< LMDB::Env->new( mapsize => ... ) >>

Default value is taken from L</cache_size> with some C<m/k> math if its set.

=attr C<maxreaders>

B<TODO:> Currently not defined due to L<< rt#98821|https://rt.cpan.org/Public/Bug/Display.html?id=98821 >>

Passes through to C<< LMDB::Env->new( maxreaders => ... ) >>

=attr C<maxdbs>

Passes through to C<< LMDB::Env->new( maxdbs => ... ) >>

Defines how many CHI namespaces ( Databases ) a path can contain.

Default is 1024.

=attr C<mode>

Passes through to C<< LMDB::Env->new( mode => ... ) >>

Defines the permissions on created DB Objects.

Defaults to C<oct 600> == C<-rw------->

=attr C<flags>

Passes through to C<< LMDB::Env->new( flags => ... ) >>

=head1 PERFORMANCE

If write performance is a little slow for you ( due to the defaults being a single
transaction per SET/GET operation, and transactions being flushed to disk when written ),
there are two ways you can make performance a little speedy.

=head2 Single Transaction Mode.

If you pass C<< single_txn => 1 >> the cache will be given a single transaction
for the life of its existence. However, pay attention to the warnings about cleaning
up properly in L</single_txn>.

Also, this mode is less ideal if you want to have two processes sharing a cache,
because the data won't be visible on the other one till it exits! ☺

=head2 C<NOSYNC> Mode.

You can also tell LMDB B<NOT> to call C<sync> at the end of every transaction,
and this will greatly improve write performance due to IO being greatly delayed.

This greatly weakens the databases consistency, but that seems like a respectable
compromise for a mere cache backend, where a missing record is a performance hit, not a loss of data.

  use LMDB_File qw( MDB_NOSYNC MDB_NOMETASYNC );
  ...
  my $cache = CHI->new(
    ...
    flags => MDB_NOSYNC | MDB_NOMETASYNC
  );

This for me cuts down an operation that takes 30 seconds worth of writes down to 6 ☺.

=head1 Comparison vs FastMmap

FastMmap is still faster for reads. Here is a simple comparison for runs
of my C<dep_changes.pl> utility which does a respectable amount of cache look-ups.

L<<
Google Docs Image
|https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=25361389&format=interactive
>>

=begin html

<center><a href="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=25361389&format=interactive"><img src="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=25361389&format=image"></a></center>

=end html

For writes, whether or not FastMmap is faster depends on settings.

=over 4

=item * C<NOSYNC> + C<single_txn = 1> tends to give faster performance than C<FastMmap>.

=item * C<NOSYNC> + C<single_txn = 0> gives comparable performance to C<FastMmap>

=item * C<SYNC>   + C<single_txn = 1> tends to give slightly worse performance than C<FastMmap>

=back

L<<
Google Docs Image
|https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=390411539&format=interactive
>>

=begin html

<center><a href="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=390411539&format=interactive"><img src="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=390411539&format=image"></a></center>

=end html

However,

=over 4

=item * C<SYNC> + C<single_txn = 0> gives much worse performance than all of the above.

=back

L<<
Google Docs Image
|https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=2027736788&format=interactive
>>

=begin html

<center><a href="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=2027736788&format=interactive"><img src="https://docs.google.com/spreadsheets/d/13PVt7N9aBnbXpqgQPPTFFO2plaLEXfNiHGefyvc3gaI/pubchart?oid=2027736788&format=image"></a></center>

=end html

=begin Pod::Coverage

BUILD DEMOLISH clear fetch fetch_multi_hashref get_keys get_namespaces max_key_length remove store store_multi

=end Pod::Coverage
