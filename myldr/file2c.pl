#!/usr/bin/perl -w
# $File: //member/autrijus/PAR/myldr/file2c.pl $ $Author: autrijus $
# $Revision: #9 $ $Change: 7151 $ $DateTime: 2003/07/27 08:31:51 $
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

$pl_text = pod_strip($pl_text, basename($pl_file)) if -e $pl_file and $pl_file =~ /\.p[lm]/i;
$pl_text = reverse $pl_text;

#  make a c-array

print OUT "char * name_$c_var = \"" . basename($pl_file) . "\";\n";
print OUT "unsigned long size_$c_var = " . length($pl_text) . ";\n";
print OUT "char $c_var\[] = {\n";
my $i = 0;
while (length($_ = chop($pl_text))) {
    print OUT "'";
    if (m/[\\"']/) {
	print OUT "\\$_";
    }
    elsif ( ord() >= 32 && ord() <= 126 ) {
	print OUT $_;
    }
    elsif ( ord() ) {
	print OUT sprintf '\%03o', ord()
    }
    else {
	print OUT '\0';
    }
    print OUT "', ";
    print OUT "\n" unless ($i++ % 16);
}
print OUT "'\\0'\n};\n";

#$c_arr =~ s/((?:'.*?',\s){16})/$1\n/sg;
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
    $pl_text =~ s/^#line 1 (.*\n)(#!.*\n)/$2#line 2 $1/g;

    return $pl_text;
}

# local variables:
# mode: cperl
# end:
