#!/usr/bin/perl

=head1 NAME

par.pl - Run Perl Archives

=head1 SYNOPSIS

To use F<Hello.pm>, F<lib/Hello.pm> or F<lib/arch/Hello.pm> from F<./foo.par>:

    % par.pl -A./foo.par -MHello 
    % par.pl -A./foo -MHello	# the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello 
    % par.pl -Ifoo -MHello 	# ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl	# only when the first argument ends in '.par'

=head1 DESCRIPTION

This stand-alone command offers roughly the same feature as
C<perl -MPAR>, except that it takes the pre-loaded F<.par>
files via C<-Afoo.par> instead of C<-MPAR=foo.par>.

The main purpose of this utility is to be feed to C<perlcc>:

    % perlcc -o par par.pl

and use the resulting stand-alone executable F<par> as an
alternative to C<perl2exe> or C<PerlApp>:

    # runs script/run.pl in archive, uses its lib/* as libraries
    % par myapp.par run.pl

=cut

use PAR;
use Archive::Zip;

my @par_args;

while (@ARGV) {
    $ARGV[0] =~ /^-([AIM])(.*)/ or last;

    if ($1 eq 'I') {
	push @INC, $2;
    }
    elsif ($1 eq 'M') {
	eval "use $2";
    }
    elsif ($1 eq 'A') {
	push @par_args, $2;
    }
}

die "Usage: $0 [-Alib.par] [-Idir] [-Mmodule] [src.par] program.pl" unless @ARGV;

$0 = shift;
PAR->import(@par_args);
do $0;

=head1 SEE ALSO

L<PAR>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
