# $File: //member/autrijus/PAR/PAR.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 1537 $ $DateTime: 2002/10/19 14:18:37 $

package PAR;
$PAR::VERSION = '0.05';

use 5.006;
use strict;

=head1 NAME

PAR - Perl Archive

=head1 VERSION

This document describes version 0.05 of PAR.

=head1 SYNOPSIS

(If you want to make an executable that contains all module,
scripts and data files, please consult L<par.pl> instead.)

Following examples assume a F<foo.par> file in Zip format;
support for compressed gzip (F<*.tgz>) format is planned.

To use F<Hello.pm>, F<lib/Hello.pm> or F<lib/arch/Hello.pm> from F<./foo.par>:

    % perl -MPAR=./foo.par -MHello
    % perl -MPAR=./foo -MHello		# the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % perl -MPAR -Ifoo.par -MHello
    % perl -MPAR -Ifoo -MHello		# ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % perl -MPAR foo.par test.pl	# only when $0 ends in '.par'
    % perl -MPAR foo.par		# looks for 'main.pl' by default

Used in a program:

    use PAR 'foo.par';
    use Hello; # reads within foo.par

    # PAR::read_file() returns a file inside any loaded PARs
    my $conf = PAR::read_file('data/MyConfig.yaml');

    # PAR::par_handle() returns an Archive::Zip handle
    my $zip = PAR::par_handle('foo.par')
    my $src = $zip->memberNamed('lib/Hello.pm')->contents;

=head1 DESCRIPTION

This module let you easily bundle a F<blib/> tree into a zip
file, called a Perl Archive, or C<PAR>.

To generate a F<.par> file, all you have to do is compress a
F<lib/> tree containing modules, e.g.:

    % perl Makefile.PL
    % make
    % cd blib
    % zip -r mymodule.par lib/

Afterwards, you can just use F<mymodule.par> anywhere in your
C<@INC>, use B<PAR>, and it would Just Work.

For maximal convenience, you can set the C<PERL5OPT> environment
variable to C<-MPAR> to enable C<PAR> processing globally (the
overhead is small if not used), or to C<-MPAR=/path/to/mylib.par>
to load a specific PAR file.

Please see L</SYNOPSIS> for most typical use cases.

=head1 NOTES

For Perl versions without I<PerlIO> support, the B<IO::Scalar> module
is needed to support C<__DATA__> sections in script and modules
inside a PAR file.

If you choose to compile F<script/par.pl> with B<perlcc>, it will
automatically include the correct module (B<PerlIO::scalar> or
B<IO::Scalar>) if you have it installed.

=cut

my $Reentrant;
our @PAR_INC;
our (@LibCache, %LibCache); # I really miss pseudohash.
our %DATACache; # cache for __DATA__ segments

sub import {
    my $class = shift;
    return if !@_ and $Reentrant++;

    foreach my $par (@_) {
	push @PAR_INC, $par if unpar($par);
    }

    push @INC, \&incpar unless grep { $_ eq \&incpar } @INC;

    if (unpar($0)) {
	push @PAR_INC, $0;

	my $has_argv = @ARGV;
	my $file = $has_argv ? shift(@ARGV) : 'main.pl';
	my $zip = $LibCache{$0};
	my $member = $zip->memberNamed($file)
		  || $zip->memberNamed("script/$file")
	    or die ( $has_argv
		? qq(Can't open perl script "$file": No such file or directory)
		: qq(No program file specified)
	    );

	$0 = $file;
	my $program = $member->contents;
	if ($program =~ s/^__DATA__\n?(.*)//ms) {
	    $DATACache{$file} = $1;
	    $program .= _wrap_data($file);
	}

	{
	    package main;
	    eval $program;
	}
	die $@ if $@;
	exit;
    }

    $Reentrant-- if !@_;
}

sub incpar {
    my ($self, $file) = @_;

    foreach my $path (@PAR_INC ? @PAR_INC : @INC) {
	my $fh = unpar($path, $file) or next;
	return $fh;
    }

    return;
}

sub read_file {
    my $file = pop;

    foreach my $zip (@LibCache) {
	my $member = $zip->memberNamed($file) or next;
	return scalar $member->contents;
    }

    return;
}

sub par_handle {
    my $par = pop;
    return $LibCache{$par};
}

sub unpar {
    my ($par, $file) = @_;
    my $zip = $LibCache{$par};

    unless ($zip) {
	unless ($par =~ /\.par$/i and -e $par) {
	    $par .= ".par";
	    return unless -e $par;
	}

	require Archive::Zip;
	$zip = Archive::Zip->new;
	next unless $zip->read($par) == Archive::Zip::AZ_OK();

	push @LibCache, $zip;
	$LibCache{$par} = $zip;
    }

    return 1 unless defined $file;

    my $member = $zip->memberNamed($file)
	      || $zip->memberNamed("lib/$file")
	      || $zip->memberNamed("lib/arch/$file") or return;

    my $fh = IO::Handle->new;
    my @lines = map "$_\n", split("\n", scalar $member->contents);

    # You did not see this undocumented jenga piece.
    return ($fh, sub {
	$_ = shift(@lines);
	if ($_ eq "__DATA__\n" or $_ eq "__END__\n") {
	    $DATACache{$par} = join('', @lines);
	    @lines = ();
	    $_ = _wrap_data($par);
	}
	return length $_;
    });
}

sub _wrap_data {
    my $key = shift;

    if (eval {require PerlIO::scalar; 1}) {
	return "use PAR (".
	       "    open(*DATA, '<', \\\$PAR::DATACache{'$key'}) ? () : ()".
	       ");\n"; 
    }
    elsif (eval {require IO::Scalar; 1}) {
	return "use IO::Scalar (".
	       "    tie(*DATA, 'IO::Scalar', \\\$PAR::DATACache{'$key'})".
	       "    ? () : ()".
	       ");\n";
    }
    else {
	# only dies when it's used
	return "use PAR (tie(*DATA, 'PAR::_data') ? () : ())\n";
    }
}

package PAR::_data;

sub TIEHANDLE { bless {}, shift }
sub AUTOLOAD {
    die "Cannot use __DATA__ sections in .par files; please install IO::Scalar first!\n"
}
sub DESTROY {}

1;

=head1 SEE ALSO

L<par.pl>

L<Archive::Zip>, L<perlfunc/require>

L<ex::lib::zip>, L<Acme::use::strict::with::pride>

=head1 ACKNOWLEDGMENTS

Nicholas Clark for pointing out the mad source filter hook within
the (also mad) coderef C<@INC> hook.

Ton Hospel for convincing me to ditch the C<Filter::Simple>
implementation.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
