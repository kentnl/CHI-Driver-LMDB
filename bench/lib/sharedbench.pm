use 5.008;    # utf8
use strict;
use warnings;
use utf8;
package       #
  sharedbench;

# ABSTRACT: misc shared things

# AUTHORITY

use Moo;
use CHI;
use Data::Serializer::Sereal;
use Path::Tiny;
use MooX::Lsub;
use Benchmark::CSV;
use Math::Random::ISAAC;

has testname => required => 1, is => ro =>;
has rootdir  => required => 1, is => ro =>;

lsub sample_size      => sub { $_[0]->total_iterations * 0.1 };
lsub total_iterations => sub { 100 };
lsub steps            => sub { 200 };

lsub key_size   => sub { 128 };
lsub value_size => sub { 128 };
lsub _real_root => sub {
  my $r = path( $_[0]->rootdir );
  my $x = $r->child('results');
  $x->mkpath;
  $x->child('write')->mkpath;
  $x->child('write_reduced')->mkpath;
  $x->child('read')->mkpath;
  $x->child('read_reduced')->mkpath;

  return $x;
};

lsub write_bench => sub {
  return Benchmark::CSV->new(
    sample_size   => $_[0]->sample_size,
    output        => $_[0]->_real_root->child('write')->child( $_[0]->testname . '.csv' ),
    timing_method => 'hires_cputime_process',
  );
};

lsub read_bench => sub {
  return Benchmark::CSV->new(
    sample_size   => $_[0]->sample_size,
    output        => $_[0]->_real_root->child('read')->child( $_[0]->testname . '.csv' ),
    timing_method => 'hires_cputime_process',
  );
};
lsub _dbs => sub { [] };

sub DEMOLISH {
  my ($self) = @_;
  delete $self->{testname};
  delete $self->{write_bench};
  delete $self->{read_bench};
}

sub add_bench {
  my ( $self, $label, @extra ) = @_;
  my $root       = Path::Tiny->tempdir;
  my $serializer = Data::Serializer::Sereal->new();
  my $chi        = CHI->new(
    expires_in     => '5h',
    key_serializer => $serializer,
    serializer     => $serializer,
    root_dir       => $root . q[],
    cache_size     => '50m',
    @extra
  );
  my ( $i, $j ) = ( 0, 0 );
  my $w_key_seq = Math::Random::ISAAC->new( unpack 'L*', "This is a benchmark" );
  my $r_key_seq = Math::Random::ISAAC->new( unpack 'L*', "This is a benchmark" );

  my $value;
  my $steps  = $self->value_size / 32;
  my $writer = sub {
    $i++;
    $chi->compute(
      $i, undef,
      sub {
        my $buf = '';
        for ( 0 .. $steps ) {
          $buf .= pack 'L', $w_key_seq->irand;
        }
        return $buf;
      }
    );
  };
  my $reader = sub {
    $j++;
    $chi->compute(
      $j, undef,
      sub {
        my $buf = '';
        for ( 0 .. $steps ) {
          $buf .= pack 'L', $r_key_seq->irand;
        }
        return $buf;
      }
    );
  };
  $self->write_bench->add_instance( $label, $writer );
  $self->read_bench->add_instance( $label, $reader );
  push @{ $self->_dbs },
    {
    root   => $root,
    chi    => $chi,
    writer => $writer,
    reader => $reader,
    };
}

sub run_write_test {
  my ($self) = @_;
  *STDOUT->autoflush(1);
  printf qq[<< %-40s >>\n], join q[,], keys %{ $self->write_bench->{instances} };
  printf qq{Writing: [%s]\rWriting: [}, q[_] x $self->steps;

  for ( 1 .. $self->steps ) {
    $self->write_bench->run_iterations( $self->total_iterations );
    print "#"

  }
  print "]\n";
}

sub run_read_test {
  my ($self) = @_;
  *STDOUT->autoflush(1);
  printf qq{Reading: [%s]\rReading: [}, q[_] x $self->steps;

  for ( 1 .. $self->steps ) {
    $self->read_bench->run_iterations( $self->total_iterations );
    print "#"

  }
  print "]\n";
}

sub reduce_results {
  my ($self) = @_;
  _reduce_results(
    200,
    $self->_real_root->child('write')->child( $self->testname . '.csv' ),
    $self->_real_root->child('write_reduced')->child( $self->testname . '.csv' ),
  );
  _reduce_results(
    200,
    $self->_real_root->child('read')->child( $self->testname . '.csv' ),
    $self->_real_root->child('read_reduced')->child( $self->testname . '.csv' ),
  );

}

sub _reduce_results {
  my ( $n, $source, $target ) = @_;
  my @headers;
  my @buckets;

  my $reader = path($source)->openr;

  @headers = split q/,/, do { my $x = scalar <$reader>; chomp $x; $x };
  while ( my $line = <$reader> ) {
    chomp $line;
    my (@line) = split q/,/, $line;
    for my $col ( 0 .. $#line ) {
      $buckets[$col] ||= [];
      push @{ $buckets[$col] }, $line[$col];
    }
  }
  my @sorted_buckets;
  for my $bucket (@buckets) {
    push @sorted_buckets, [ sort { $a <=> $b } @{$bucket} ];
  }
  my $step = 1;
  while ( ( $#{ $sorted_buckets[0] } ) / $step > $n ) {
    $step++;
  }

  my $writer = path($target)->openw;
  $writer->printf( "%s\n", join q[,], @headers );
  for ( my $i = 0 ; $i < $#{ $sorted_buckets[0] } ; $i += $step ) {
    my @row;
    for my $bucket ( 0 .. $#sorted_buckets ) {
      push @row, $sorted_buckets[$bucket]->[$i];
    }
    $writer->printf( "%s\n", join q[,], @row );
  }

}

1;

