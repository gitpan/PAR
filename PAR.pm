# $File: //member/autrijus/PAR/PAR.pm $ $Author: autrijus $
# $Revision: #48 $ $Change: 2323 $ $DateTime: 2002/11/23 14:21:11 $

package PAR;
$PAR::VERSION = '0.49';

use 5.006;
use strict;
use warnings;
use Config ();

=head1 NAME

PAR - Perl Archive Toolkit

=head1 VERSION

This document describes version 0.49 of PAR, released November 23, 2002.

=head1 SYNOPSIS

(If you want to make an executable that contains all module, scripts and
data files, please consult L<pp> instead.)

Following examples assume a F<foo.par> file in Zip format; support for
compressed gzip (F<*.tgz>) format is under consideration.

To use F<Hello.pm> from F<./foo.par>:

    % perl -MPAR=./foo.par -MHello
    % perl -MPAR=./foo -MHello		# the .par part is optional

Same thing, but search F<foo.par> in the C<@INC>;

    % perl -MPAR -Ifoo.par -MHello
    % perl -MPAR -Ifoo -MHello		# ditto

The search path for the above two examples are:

    /
    /lib/
    /arch/
    /i386-freebsd/		# i.e. $Config{archname}
    /5.8.0/			# i.e. $Config{version}
    /5.8.0/i386-freebsd/	# both of the above

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % perl -MPAR foo.par test.pl	# only when $0 ends in '.par'

However, if the F<.par> archive contains either F<main.pl> or
F<script/main.pl>, then it is used instead:

    % perl -MPAR foo.par test.pl	# runs main.pl, with 'test.pl' as @ARGV

Use in a program:

    use PAR 'foo.par';
    use Hello; # reads within foo.par

    # PAR::read_file() returns a file inside any loaded PARs
    my $conf = PAR::read_file('data/MyConfig.yaml');

    # PAR::par_handle() returns an Archive::Zip handle
    my $zip = PAR::par_handle('foo.par')
    my $src = $zip->memberNamed('lib/Hello.pm')->contents;

=head1 DESCRIPTION

This module lets you easily bundle a typical F<blib/> tree into a zip
file, called a Perl Archive, or C<PAR>.

To generate a F<.par> file, all you have to do is compress the modules
under F<arch/> and F<lib/>, e.g.:

    % perl Makefile.PL
    % make
    % cd blib
    % zip -r mymodule.par arch/ lib/

Afterwards, you can just use F<mymodule.par> anywhere in your C<@INC>,
use B<PAR>, and it will Just Work.

For maximal convenience, you can set the C<PERL5OPT> environment
variable to C<-MPAR> to enable C<PAR> processing globally (the overhead
is small if not used), or to C<-MPAR=/path/to/mylib.par> to load a
specific PAR file.  Alternatively, consider using the F<par.pl>
utility bundled with this module.

Note that self-containing scripts and executables created with F<par.pl>
and F<pp> may also be used as F<.par> archives:

    % pp -O packed.exe source.pl	# generate packed.exe
    % perl -MPAR=packed.exe other.pl	# this can also work
    % perl -MPAR -Ipacked.exe other.pl	# ditto

Please see L</SYNOPSIS> for most typical use cases.

=head1 NOTES

Since version 0.10, this module supports loading XS modules by overriding
B<DynaLoader> boostrapping methods; it writes shared object file to a
temporary file at the time it is needed, and removes it when the program
terminates.  Currently there are no plans to leave them around for the
next time, but if you need the functionality, just mail me. ;-)

=cut

use vars qw(@PAR_INC);			# explicitly stated PAR library files
use vars qw(@LibCache %LibCache);	# I really miss pseudohash.

my $ver	 = $Config::Config{version};
my $arch = $Config::Config{archname};

my $_reentrant;				# flag to avoid recursive import
sub import {
    my $class = shift;
    return if !@_ and $_reentrant++;

    foreach my $par (@_) {
	push @PAR_INC, $par if unpar($par, undef, undef, 1);
    }

    push @INC, \&find_par unless grep { $_ eq \&find_par } @INC;

    require PAR::Heavy;
    PAR::Heavy::_init_dynaloader();

    if (unpar($0)) {
	$PAR::__reading = 1;
	push @PAR_INC, $0;

	my $file;
	my $zip = $LibCache{$0};
	my $member = $zip->memberNamed("main.pl")
		  || $zip->memberNamed("script/main.pl");

	if ($member) {
	    $file = 'main.pl';
	}
	else {
	    die "Usage: $0 script_file_name.\n" unless @ARGV;

	    $file = shift(@ARGV);
	    $member = $zip->memberNamed($file)
		   || $zip->memberNamed("script/$file")
		or die qq(Can't open perl script "$file": No such file or directory);
	}

	my $fh = _tmpfile();
	print $fh "package main; shift \@INC;\n#line 1 \"$file\"\n";
	$member->extractToFileHandle($fh);
	seek ($fh, 0, 0);
	unshift @INC, sub { $fh };

	$PAR::__reading = 0;
	{ do 'main'; die $@ if $@; exit }
    }

    $_reentrant-- if !@_;
}

sub find_par {
    my ($self, $file, $member_only) = @_;

    foreach my $path (@PAR_INC ? @PAR_INC : @INC) {
	my $rv = unpar($path, $file, $member_only, 1);
	return $rv if defined($rv);
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
    my ($par, $file, $member_only, $allow_other_ext) = @_;
    my $zip = $LibCache{$par};

    local $PAR::__reading = 1;

    unless ($zip) {
	unless (($allow_other_ext or $par =~ /\.par\z/i) and -f $par) {
	    $par .= ".par";
	    return unless -f $par;
	}

	require Compress::Zlib;
	require Archive::Zip;

	$zip = Archive::Zip->new;
	return unless $zip->read($par) == Archive::Zip::AZ_OK();

	push @LibCache, $zip;
	$LibCache{$par} = $zip;
    }

    return 1 unless defined $file;

    my $member = $zip->memberNamed($file)
	      || $zip->memberNamed("lib/$file")
	      || $zip->memberNamed("arch/$file")
	      || $zip->memberNamed("$arch/$file")
	      || $zip->memberNamed("$ver/$file")
	      || $zip->memberNamed("$ver/$arch/$file") or return;

    return $member if $member_only;

    my $fh = _tmpfile();
    die "Bad Things Happened..." unless $fh;
    $member->extractToFileHandle($fh);
    seek ($fh, 0, 0);

    return $fh;
}

sub _tmpfile {
    # From Mattia Barbon <MBARBON@cpan.org>:
    # Under Win32, IO::File->new_tmpfile uses the C function tmpfile(),
    # but the implementation provided by MS creates the temporary files in the
    # root directory, which is likely not to be writable by ordinary users.
    # using File::Temp::tempfile solves the problem *except* for files containing
    # a __DATA__/__END__ <guess>since perl copies(dups?) the filehandle,
    # at the time File::Temp calls unlink, there is still an open handle around,
    # and Win32 can't delete opened files...
    #
    my $fh = IO::File->new_tmpfile;
    unless( $fh ) {
	require File::Temp;

	# under Win32, the file is created with O_TEMPORARY,
	# and will be deleted by the C runtime; having File::Temp
	# delete it has the only effect of giving an ugly warnings
	$fh = File::Temp::tempfile( UNLINK => ($^O ne 'MSWin32') )
	    or die "Cannot create temporary file: $!";
    }
    return $fh;
}

1;

=head1 SEE ALSO

My presentation, "Introduction to Perl Archive Toolkit":
L<http://www.autrijus.org/par-intro/slide001.html>

L<par.pl>, L<pp>

L<Archive::Zip>, L<perlfunc/require>

L<ex::lib::zip>, L<Acme::use::strict::with::pride>

=head1 ACKNOWLEDGMENTS

Nicholas Clark for pointing out the mad source filter hook within the
(also mad) coderef C<@INC> hook, as well as (even madder) tricks one
can play with PerlIO to avoid source filtering.

Ton Hospel for convincing me to ditch the C<Filter::Simple>
implementation.

Uri Guttman for suggesting C<read_file> and C<par_handle> interfaces.

Antti Lankila for making me implement the self-contained executable
options via C<par.pl -O>.

See the F<AUTHORS> file in the distribution for a list of people who
have sent helpful patches, ideas or comments.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
