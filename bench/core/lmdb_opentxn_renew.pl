#!/usr/bin/env perl
# FILENAME: lmdb_opentxn.pl
# CREATED: 09/19/14 06:16:03 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Benchmark OpenTXN Timing.

use strict;
use warnings;
use utf8;

use LMDB_File qw( :all );
use FindBin;
use Benchmark::CSV;
use Path::Tiny qw( path );
use lib path($FindBin::Bin)->parent->child('lib')->stringify;
use sharedbench;

my $selfdir = path($FindBin::Bin);

$selfdir->child('results')->mkpath;
$selfdir->child('results_reduced')->mkpath;

my $outfile = $selfdir->child('results/lmdb_opentxn_renew.csv');
my $redfile = $selfdir->child('results_reduced/lmdb_opentxn_renew.csv');

my $bench = Benchmark::CSV->new(
  sample_size   => 10,
  timing_method => 'hires_cputime_process',
  output        => $outfile,
);

my $tdir = Path::Tiny->tempdir;
my $dbi;
my $env = LMDB::Env->new(
  "$tdir",
  {
    mapsize => ( 50 * 1024 * 1024 ),
    maxdbs  => 1024,
  }
);
my $txn_reader;
{
  my $txn = $env->BeginTxn();
  $dbi = $txn->open( 'test', MDB_CREATE );
  my $db = LMDB_File->new( $txn, $dbi );
  $txn->commit;
}

sub open_write_close {
  my $txn = $env->BeginTxn();
  my $db = LMDB_File->new( $txn, $dbi );
  $db->put( 'a' => 'b' );
  $txn->commit;
}

sub open_read_close {

  #if ( not $txn_reader ) {
  $txn_reader = $env->BeginTxn(MDB_RDONLY);

  #}
  my $db = LMDB_File->new( $txn_reader, $dbi );
  my $get = $db->get('a');
  $txn_reader->commit;
}

sub open_read_twice_close {

  #if ( not $txn_reader ) {
  $txn_reader = $env->BeginTxn(MDB_RDONLY);

  #}
  my $db   = LMDB_File->new( $txn_reader, $dbi );
  my $get  = $db->get('a');
  my $getb = $db->get('a');
  $txn_reader->commit;
}

sub open_close_txn {
  my $txn = $env->BeginTxn();
  my $db = LMDB_File->new( $txn, $dbi );
  $txn->commit;
}
open_write_close;
open_close_txn;
open_read_close;
open_read_twice_close;
$bench->add_instance( 'open+close transaction'        => \&open_close_txn );
$bench->add_instance( 'open+read+close transaction'   => \&open_read_close );
$bench->add_instance( 'open+readx2+close transaction' => \&open_read_twice_close );
*STDOUT->autoflush(1);
printf qq{Running: [%s]\rWriting: [}, q[_] x 200;

for ( 1 .. 200 ) {
  $bench->run_iterations(2000);
  print "#"

}
print "]\n";
sharedbench::_reduce_results( 500, $outfile, $redfile );
