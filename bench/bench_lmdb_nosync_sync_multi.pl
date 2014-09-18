#!/usr/bin/env perl
# FILENAME: bench_fastmmap.pl
# CREATED: 09/18/14 15:37:25 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: benchmark fastmmap performance isolated.

use strict;
use warnings;
use utf8;

use FindBin;
use Path::Tiny;
use LMDB_File qw( :envflags );
use lib path($FindBin::Bin)->child('lib')->stringify;
use sharedbench;

my $sb = sharedbench->new(
  testname => 'lmdb_nosync_sync_multi',
  rootdir  => path($FindBin::Bin),
);
$sb->add_bench(
  'LMDB SYNC=0 METASYNC=1 TX=MULTI',
  driver => 'LMDB',
  flags  => MDB_NOSYNC
);
$sb->run_write_test;
system('sync');
$sb->run_read_test;
$sb->reduce_results;
