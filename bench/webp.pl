#!/usr/bin/env perl
# FILENAME: webp.pl
# CREATED: 09/18/14 20:16:42 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Convert PNG files to WebP

use strict;
use warnings;
use utf8;

use Path::Tiny qw(path);
use FindBin;

for my $child ( grep { $_->basename =~ /.png$/ } path($FindBin::Bin)->children ) {
  my $target = path($FindBin::Bin)->child( $child->basename('.png') . '.webp' );
  system( 'cwebp', '-lossless', '-q', '100', '-m', '6', '-alpha_filter', 'best', '-progress', $child, '-o', $target );
}

