#!/usr/bin/perl
# $File: //member/autrijus/PAR/script/makepar.pl $ $Author: autrijus $
# $Revision: #12 $ $Change: 1820 $ $DateTime: 2002/11/02 01:53:52 $

=head1 NAME

makepar.pl - Make Perl Archives

=head1 SYNOPSIS

Checking module dependencies for F</home/test.pl>:

    % makepar.pl /home/test.pl

To turn F</home/test.pl> into a self-contained F<foo.pl> that runs
anywhere with a matching version of core perl (5.6 or above):

    % makepar.pl -S -B -O./foo.par /home/test.pl
    % par.pl -b -O./foo.pl foo.par	# or -B to bundle core modules
    % perl foo.pl			# runs anywhere with core modules

Same thing, but making a self-contained binary executable F<foo.exe>
instead, by bundling the perl executable itself:

    % makepar.pl -B -O./foo.par /home/test.pl
    % perlcc -o par.exe par.pl		# only need to do this once
    % par.exe -B -O./foo.exe foo.par	# self-contained .exe
    % foo.exe				# runs anywhere with same OS

=head1 DESCRIPTION

This module makes a zip-compressed I<Perl Archive> (B<PAR>) file from
a perl script or module, by putting all included library files into
the archive's C<lib/> directory, and optionally store the script
themselves into the C<script/> directory.

To generate F<./foo.par> from the script F</home/test.pl>, do this:

    % makepar.pl -O./foo.par /home/test.pl
    % makepar.pl -O./foo /home/test.pl		# the .par part is optional

Same thing, but include F</home/test.pl> in the PAR as F<script/test.pl>:

    % makepar.pl -b -O./foo.par /home/test.pl
    % makepar.pl -b -O./foo /home/test.pl	# ditto

Same thing, but include F</home/test.pl> in the PAR as F<script/main.pl>:

    % makepar.pl -B -O./foo.par /home/test.pl	# turns first .pl into main.pl

You can specify additional include directories with B<-I> and B<-M>;

    % makepar.pl -MTest::More -I/tmp -O./foo.par /home/test.pl

The B<-S> switch will cause this program to ignore all core modules,
while the B<-s> switch just ignores pure-perl core modules:

    % makepar.pl -s -O./foo.par /home/test.pl	# just skip $Config{privlib}
    % makepar.pl -S -O./foo.par /home/test.pl	# skips privlib and archlib

=cut

use Module::ScanDeps;

# Initialization {{{
use strict;
use Config ();
$|++;

my ($out, $bundle, $skip);
while (@ARGV) {
    $ARGV[0] =~ /^-([bBsSO]+|[IM])(.*)/ or last;
    shift;
    if ($1 eq 'I') {
	push @INC, $2;
    }
    if ($1 eq 'M') {
	my $mod = $2;
	$mod =~ s/::/\//g;
	push @ARGV, "$mod.pm";
    }
    else {
	$out	  = $2	     if index($1, 'O') > -1;
	$bundle	||= 'script' if index($1, 'b') > -1;
	$bundle	  = 'main'   if index($1, 'B') > -1;
	$skip	||= 'arch'   if index($1, 's') > -1;
	$skip     = 'core'   if index($1, 'S') > -1;
    }
}

$out .= '.par' if defined($out) and $out !~ /\./;

die "Usage: $0 [ -B|-b ] [ -S|-s ] [ -Ooutput.par ] [ -Idir ]\n". (' ' x length($0)).
    "        [ -Mmodule ] [ script1 script2 ... ]\n" unless @ARGV;

# }}}

# Main program {{{

my %map = %{Module::ScanDeps::scan_deps(@ARGV)};

my $zip;
if ($out) {
    require Archive::Zip;
    $zip = Archive::Zip->new;
}

my $size;
foreach (sort {$map{$a} cmp $map{$b}} grep length $map{$_}, keys %map) {
    next if $skip and $map{$_} eq "$Config::Config{privlib}/$_";
    next if $skip eq 'core' and $map{$_} eq "$Config::Config{archlib}/$_";

    print "$map{$_}\n";
    next unless $zip;
    $size += -s $map{$_};
    $zip->addFile($map{$_}, "lib/$_");
}

if ($bundle and $zip) {
    require File::Basename;
    for (@ARGV) {
	$size += -s;
	if ($bundle eq 'main') {
	    $zip->addFile($_, "script/main.pl");
	    $bundle = 'script';
	}
	else {
	    $zip->addFile($_, "script/".File::Basename::basename($_))
	}
    }
}

if ($zip) {
    $zip->writeToFileNamed($out);
    my $newsize = -s $out;
    printf "*** %s: %d bytes read, %d compressed, %2.2d%% saved.\n",
	$out, $size, $newsize, (100 - ($newsize / $size * 100));
}

# }}}

1;
__END__

=head1 SEE ALSO

L<PAR>, L<par.pl>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

Based on the F<perl2exe-scan.pl> by Indy Singh E<lt>indy@indigostar.comE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.
Copyright 1998, 2002 by IndigoSTAR Software L<http://www.indigostar.com/>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
