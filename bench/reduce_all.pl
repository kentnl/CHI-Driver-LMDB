#!/usr/bin/env perl
# FILENAME: bench_fastmmap.pl
# CREATED: 09/18/14 15:37:25 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: benchmark fastmmap performance isolated.

use strict;
use warnings;
use utf8;

use FindBin;
use Path::Tiny;
use lib path($FindBin::Bin)->child('lib')->stringify;
use sharedbench;

my $nresults = 500;

for my $child ( path($FindBin::Bin)->child('results/write')->children ) {
  my $out = path($FindBin::Bin)->child('results/write_reduced')->child( $child->basename );
  sharedbench::_reduce_results( $nresults, $child, $out );
}
for my $child ( path($FindBin::Bin)->child('results/read')->children ) {
  my $out = path($FindBin::Bin)->child('results/read_reduced')->child( $child->basename );
  sharedbench::_reduce_results( $nresults, $child, $out );
}
