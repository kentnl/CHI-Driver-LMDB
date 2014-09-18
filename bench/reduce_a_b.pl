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

sharedbench::_reduce_results( $nresults, path( $ARGV[0] ), path( $ARGV[1] ) );

