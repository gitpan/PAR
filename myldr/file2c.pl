#!/usr/bin/perl -w
# $File: //member/autrijus/PAR/myldr/file2c.pl $ $Author: autrijus $
# $Revision: #6 $ $Change: 5898 $ $DateTime: 2003/05/16 16:30:10 $
#
# Copyright (c) 2002 Mattia Barbon.
# Copyright (c) 2002 Autrijus Tang.
# This package is free software; you can redistribute it and/or
# modify it under the same terms as Perl itself.

use File::Basename;
use strict;
my $give_help = 0;
my $pl_file = shift;
my $c_file = shift;
my $c_var = shift;

$give_help ||= ( !defined $pl_file or
                !defined $c_file or
                !defined $c_var );
$pl_file ||= '';
$c_file ||= '';
$give_help ||= !-f $pl_file;
if( $give_help ) {
  print <<EOT;
Usage: $0 file.pl file.c c_variable
EOT

  exit 1;
}

open IN, "< $pl_file" or die "open '$pl_file': $!";
open OUT, "> $c_file" or die "open '$c_file': $!";
binmode IN; binmode OUT;

# read perl file
undef $/;
my $pl_text = <IN>;
close IN;

$pl_text = pod_strip($pl_text, basename($pl_file)) if -e $pl_file;

#  make a c-array
sub map_fun { local $_ = $_[0];
              m/[\\"']/ and return "\\$_";
              ord() >= 32 && ord() <= 127 && return $_;
              return sprintf '\0%o', ord };

my @c_chars = map { map_fun($_) } split '', $pl_text;
my $c_arr = "static char $c_var\[] = { " .
  ( join ', ', map { "'$_'" } @c_chars ) .
  ", '\\0' };\n";

print OUT $c_arr;
close OUT;

sub pod_strip {
    my ($pl_text, $filename) = @_;

    local $^W;
    my $line = 1;
    $pl_text =~ s{(
	(\A|.*?\n)
	=(?:head\d|pod|begin|item|over|for|back|end)\b
	(?:.*?\n)
	(?:=cut[\t ]*[\r\n]*?|\Z)
	(\r?\n)?
    )}{
	my ($pre, $post) = ($2, $3);
        "$pre#line " . (
	    $line += ( () = ( $1 =~ /\n/g ) )
	) . $post;
    }gsex;
    $pl_text = '#line 1 "' . ($filename) . "\"\n" . $pl_text
        if length $filename;

    return $pl_text;
}

# local variables:
# mode: cperl
# end:
