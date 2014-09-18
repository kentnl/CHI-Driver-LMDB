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

my $outfile = $selfdir->child('results/lmdb_opentxn.csv');
my $redfile = $selfdir->child('results_reduced/lmdb_opentxn.csv');

my $bench = Benchmark::CSV->new(
  sample_size   => 10,
  timing_method => 'hires_cputime_process',
  output        => $outfile,
);

my $tdir = Path::Tiny->tempdir;

my $env = LMDB::Env->new(
  "$tdir",
  {
    mapsize => ( 50 * 1024 * 1024 ),
    maxdbs  => 1024,
  }
);

sub open_write_close {
  my $txn = $env->BeginTxn();
  my $db  = $txn->OpenDB(
    {
      dbname => 'test',
      flags  => MDB_CREATE,
    }
  );
  $db->put( 'a' => 'b' );
  $txn->commit;
}

sub open_read_close {
  my $txn = $env->BeginTxn();
  my $db  = $txn->OpenDB(
    {
      dbname => 'test',
      flags  => MDB_CREATE,
    }
  );
  my $get = $db->get('a');
  $txn->commit;
}

sub open_read_twice_close {
  my $txn = $env->BeginTxn();
  my $db  = $txn->OpenDB(
    {
      dbname => 'test',
      flags  => MDB_CREATE,
    }
  );
  my $get  = $db->get('a');
  my $getb = $db->get('a');

  $txn->commit;
}

sub open_close_txn {
  my $txn = $env->BeginTxn();
  my $db  = $txn->OpenDB(
    {
      dbname => 'test',
      flags  => MDB_CREATE,
    }
  );
  $txn->commit;
}
open_close_txn;
open_write_close;
open_read_close;
open_read_twice_close;
$bench->add_instance( 'open+close transaction' => \&open_close_txn );

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
