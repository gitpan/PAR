# $File: //member/autrijus/PAR/PAR.pm $ $Author: autrijus $
# $Revision: #18 $ $Change: 1692 $ $DateTime: 2002/10/27 10:15:27 $

package PAR;
$PAR::VERSION = '0.14';

use 5.006;
use strict;
use Config ();

=head1 NAME

PAR - Perl Archive

=head1 VERSION

This document describes version 0.14 of PAR, released October 27, 2002.

=head1 SYNOPSIS

(If you want to make an executable that contains all module, scripts and
data files, please consult L<par.pl> instead.)

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
    /5.8.0/			# i.e. Perl version number
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

This module let you easily bundle a typical F<blib/> tree into a zip
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

Please see L</SYNOPSIS> for most typical use cases.

=head1 NOTES

For Perl versions without I<PerlIO> support, the B<IO::Scalar> module is
needed to support C<__DATA__> sections in script and modules inside a
PAR file.

If you choose to compile F<script/par.pl> with B<perlcc>, it will
automatically include the correct module (B<PerlIO::scalar> or
B<IO::Scalar>) if you have it installed.

Since version 0.10, this module supports loading XS modules by overriding
B<DynaLoader> boostrapping methods; it writes shared object file to a
temporary file at the time it is needed, and removes it when the program
terminates.  Currently there are no plans to leave them around for the
next time, but if you need the functionality, just mail me. ;-)

=cut

use vars qw(@PAR_INC);			# explicitly stated PAR library files
use vars qw(@LibCache %LibCache);	# I really miss pseudohash.
use vars qw(%DATACache %DLCache);	# cache for __DATA__ segments

my $ver		= $^V ? sprintf("%vd", $^V) : $];
my $arch	= $Config::Config{archname};
my $dl_dlext	= $Config::Config{dlext};

my $_reentrant;				# flag to avoid recursive import
sub import {
    my $class = shift;
    return if !@_ and $_reentrant++;

    foreach my $par (@_) {
	push @PAR_INC, $par if unpar($par);
    }

    push @INC, \&find_par unless grep { $_ eq \&find_par } @INC;

    _init_dynaloader();

    if (unpar($0)) {
	push @PAR_INC, $0;

	my $file;
	my $zip = $LibCache{$0};
	my $member = $zip->memberNamed("main.pl")
		  || $zip->memberNamed("script/main.pl");

	if ($member) {
	    $file = 'main.pl';
	}
	else {
	    die qq(No program file specified) unless @ARGV;

	    my $file = shift(@ARGV);
	    $member = $zip->memberNamed($file)
		   || $zip->memberNamed("script/$file")
		or die qq(Can't open perl script "$file": No such file or directory);
	}

	my $program = $member->contents;
	if ($program =~ s/^__DATA__\n?(.*)//ms) {
	    $DATACache{$file} = $1;
	    $program .= _wrap_data($file);
	}

	{
	    package main;
	    $0 = $file;
	    eval $program;
	    die $@ if $@;
	}

	exit;
    }

    $_reentrant-- if !@_;
}

sub find_par {
    my ($self, $file, $member_only) = @_;

    foreach my $path (@PAR_INC ? @PAR_INC : @INC) {
	next if ref $file;
	my $rv = unpar($path, $file, $member_only);
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
    my ($par, $file, $member_only) = @_;
    my $zip = $LibCache{$par};

    unless ($zip) {
	unless ($par =~ /\.par$/i and -e $par) {
	    $par .= ".par";
	    return unless -e $par;
	}

	require Compress::Zlib;
	require Archive::Zip;

	$zip = Archive::Zip->new;
	next unless $zip->read($par) == Archive::Zip::AZ_OK();

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

    # If lucky enough to have PerlIO, use it instead of ugly filtering.
    if (eval { require PerlIO::scalar; 1 }) {
	return eval q{
	    open my $fh, '<:scalar', \(scalar $member->contents);
	    $fh;
	}
    }

    # You did not see this undocumented super-jenga piece.
    my @lines = split(/(?<=\n)/, scalar $member->contents);

    return (sub {
	$_ = shift(@lines);
	if (/^__(END|DATA)__$/) {
	    $DATACache{$par} = join('', @lines);
	    @lines = ();
	    $_ = _wrap_data($par, 1);
	}
	return length $_;
    });
}

sub _wrap_data {
    my ($key, $skip_perlio) = @_;

    if (!$skip_perlio and eval {require PerlIO::scalar; 1}) {
	return "use PerlIO::scalar (".
	       "    open(*DATA, '<:scalar', \\\$PAR::DATACache{'$key'}) ? () : ()".
	       ");\n"; 
    }
    elsif (eval {require IO::Scalar; 1}) {
	# This will first load IO::Scalar, *then* tie the handles.
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

########################################################################
# Dynamic inclusion of XS modules

my ($bootstrap, $dl_findfile);	# caches for code references
sub _init_dynaloader {
    return if $bootstrap;
    return unless eval { require DynaLoader; DynaLoader::dl_findfile(); 1 };

    $bootstrap   = \&DynaLoader::bootstrap;
    $dl_findfile = \&DynaLoader::dl_findfile;

    no strict 'refs';

    local $^W;
    *{'DynaLoader::bootstrap'}   = \&_bootstrap;
    *{'DynaLoader::dl_findfile'} = \&_dl_findfile;
}

sub _dl_findfile {
    # print "Finding $_[-1]. DLCache reads ", %DLCache, "\n";

    return $DLCache{$_[-1]} if exists $DLCache{$_[-1]};
    return $dl_findfile->(@_);
}

sub _bootstrap {
    my (@args) = @_;
    my ($module) = $args[0];
    my (@dirs, $file);

    if ($module) {
	my @modparts = split(/::/, $module);
	my $modfname = $modparts[-1];

	$modfname = &DynaLoader::mod2fname(\@modparts)
	    if defined &DynaLoader::mod2fname;

	if (($^O eq 'NetWare') && (length($modfname) > 8)) {
	    $modfname = substr($modfname, 0, 8);
	}

	my $modpname = join((($^O eq 'MacOS') ? ':' : '/'), @modparts);
	my $file = "auto/$modpname/$modfname.$dl_dlext";

	# print "Trying to load $file with DLCache $DLCache{$file}\n";

	if (!$DLCache{$file}++ and my $member = find_par(undef, $file, 1)) {
	    require File::Temp;

	    my ($fh, $filename) = File::Temp::tempfile(
		SUFFIX	=> ".$dl_dlext",
		UNLINK	=> 1
	    );

	    print $fh $member->contents;
	    close $fh;

	    $DLCache{$modfname} = $filename;
	}
    }

    $bootstrap->(@args);
}

########################################################################
# Stub __DATA__ filehandle

package PAR::_data;

sub TIEHANDLE {
    return bless({}, shift);
}

sub DESTROY {
}

sub AUTOLOAD {
    die "Cannot use __DATA__ sections in .par files; ".
        "please install IO::Scalar first!\n";
}

1;

=head1 SEE ALSO

L<par.pl>

L<Archive::Zip>, L<perlfunc/require>

L<ex::lib::zip>, L<Acme::use::strict::with::pride>

L<PerlIO::scalar>, L<IO::Scalar>

=head1 ACKNOWLEDGMENTS

Nicholas Clark for pointing out the mad source filter hook within the
(also mad) coderef C<@INC> hook, as well as (even madder) tricks one
can play with PerlIO to avoid source filtering.

Ton Hospel for convincing me to ditch the C<Filter::Simple>
implementation.

Uri Guttman for suggesting C<read_file> and C<par_handle> interfaces.

Antti Lankila for making me implement the self-contained executable
options via C<par.pl -O>.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
