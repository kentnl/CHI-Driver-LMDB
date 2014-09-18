#!/usr/bin/env perl
# FILENAME: webp.pl
# CREATED: 09/18/14 20:16:42 by Kent Fredric (kentnl) <kentfredric@gmail.com>
# ABSTRACT: Convert PNG files to WebP

use strict;
use warnings;
use utf8;

use Path::Tiny qw(path);
use FindBin;

for my $child ( grep { $_->basename =~ /.png$/ } path($FindBin::Bin)->children )
{
    my $target =
      path($FindBin::Bin)->child( $child->basename('.png') . '.webp' );
    my $tn =
      path($FindBin::Bin)->child( $child->basename('.png') . '.tn.webp' );

    my ( $ox, $oy ) = ( 1300, 768 );
    my ( $nx, $ny ) = ( 400 );
    $ny = int( $oy / $ox * $nx );
    system(
        'cwebp',     '-lossless', '-q',            '100',
        '-m',        '6',         '-alpha_filter', 'best',
        '-progress', $child,      '-o',            $target
    );
    system( 'cwebp', '-q', '80', '-m', '6', '-noalpha', '-mt','-af','-progress', '-resize', $nx, $ny, $child, '-o', $tn );

}

