#!/usr/bin/perl
# $File: //member/autrijus/PAR/script/par.pl $ $Author: autrijus $
# $Revision: #10 $ $Change: 1693 $ $DateTime: 2002/10/27 10:16:25 $

package __par_pl;

use strict;
use Config ();
use File::Temp ();

=head1 NAME

par.pl - Run Perl Archives

=head1 SYNOPSIS

To use F<Hello.pm>, F<lib/Hello.pm> or F<arch/Hello.pm> from
F<./foo.par>:

    % par.pl -A./foo.par -MHello 
    % par.pl -A./foo -MHello	# the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello 
    % par.pl -Ifoo -MHello 	# ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl	# only when $ARGV[0] ends in '.par'
    % par.pl foo.par		# looks for 'main.pl' by default

You can also make a self-containing script containing a PAR file :

    % par.pl -O./foo.pl foo.par
    % ./foo.pl test.pl		# same as above

To embed the necessary shared objects for PAR's execution (like
C<Zlib>, C<IO>, C<Cwd>, etc), use the B<-B> flag:

    % par.pl -B -O./foo.pl foo.par
    % ./foo.pl test.pl		# takes care of XS dependencies

=head1 DESCRIPTION

This stand-alone command offers roughly the same feature as C<perl
-MPAR>, except that it takes the pre-loaded F<.par> files via
C<-Afoo.par> instead of C<-MPAR=foo.par>.

The main purpose of this utility is to be feed to C<perlcc>:

    % perlcc -o par par.pl

and use the resulting stand-alone executable F<par> to run F<.par>
files:

    # runs script/run.pl in archive, uses its lib/* as libraries
    % par myapp.par run.pl	# runs run.pl or script/run.pl in myapp.par

However, if the F<.par> archive contains either F<main.pl> or
F<script/main.pl>, it is used instead:

    % par myapp.par run.pl	# runs main.pl, with 'run.pl' as @ARGV

Finally, as an alternative to C<perl2exe> or C<PerlApp>, the C<-o>
option makes a stand-alone binary from a PAR file:

    % par -Omyapp myapp.par	# makes a stand-alone executable
    % ./myapp run.pl		# same as above
    % ./myapp -Omyap2 myapp.par	# makes a ./myap2, identical to ./myapp
    % ./myapp -Omyap3 myap3.par	# makes another app with different PAR

The format for the stand-alone executable is simply concatenating the
following elements:

=over 4

=item * The executable itself

Either in plain-text (F<par.pl>) or native executable format (F<par>
or F<par.exe>).

=item * Any number of embedded shared objects

These are typically used for bootstrapping PAR's various XS dependencies.
Each section begins with the magic string "C<FILE>", length of file name
in C<pack('N')> format, file name (F<auto/.../>), file length in
C<pack('N')>, and the file's content (not compressed).

=item * One PAR file

This is just a zip file beginning with the magic string "C<PK\003\004>".

=item * Ending magic string

Finally there must be a 8-bytes magic string: "C<\012PAR.pm\012>".

=back

=head1 NOTES

After installation, if you want to enable stand-alone binary support,
please apply the included patch to the B::C module first (5.8.0 only,
5.6.1 does not need this):

    % patch `perl -MB::C -e'print $INC{"B/C.pm"}'` < patches/perl580.diff

and then:

    % perlcc -o /usr/local/bin/par script/par.pl

Afterwards, you can generate self-executable PAR files by:

    # put a main.pl inside myapp.par to run it automatically
    % par -O./myapp myapp.par

The C<-B> flag described earlier is particularly useful here,
to build a truly self-containing executable:

    # bundle all needed shared objects (or F<.dll>s)
    % par -B -O./myapp myapp.par

=cut

my @par_args;
my ($out, $bundle);

while (@ARGV) {
    $ARGV[0] =~ /^-([AIMOB])(.*)/ or last;

    if ($1 eq 'I') {
	push @INC, $2;
    }
    elsif ($1 eq 'M') {
	eval "use $2";
    }
    elsif ($1 eq 'A') {
	push @par_args, $2;
    }
    elsif ($1 eq 'O') {
	$out = $2;
    }
    elsif ($1 eq 'B') {
	$bundle = $2;
    }

    shift(@ARGV);
}

my $fh;
my ($start_pos, $data_pos);

{
    require IO::File;
    $fh = IO::File->new;
    last unless $fh->open($0);

    binmode($fh);

    my $buf;
    $fh->seek(-8, 2);
    $fh->read($buf, 8);
    last unless $buf eq "\nPAR.pm\n";

    $fh->seek(-12, 2);
    $fh->read($buf, 4);
    $fh->seek(-12 - unpack("N", $buf), 2);
    $fh->read($buf, 4);

    $data_pos = $fh->tell - 4;

    while ($buf eq "FILE") {
	$fh->read($buf, 4);
	$fh->read($buf, unpack("N", $buf));

	my ($basename, $ext) = ($buf =~ m|.*/(.*)(\..*)|);
	my ($out, $filename) = File::Temp::tempfile(
	    SUFFIX	=> $ext,
	    UNLINK	=> 1
	);

	$PAR::DLCache{$buf}++;
	$PAR::DLCache{$basename} = $filename;

	$fh->read($buf, 4);
	$fh->read($buf, unpack("N", $buf));
	print $out $buf;
	close $out;

	$fh->read($buf, 4);
    }

    last unless $buf eq "PK\003\004";
    
    $start_pos = $fh->tell - 4;
}

if ($out) {
    my $par = shift(@ARGV);

    open PAR, '<', $par or die $!;
    binmode(PAR);

    local $/ = \4;
    die "$par is not a PAR file" unless <PAR> eq "PK\003\004";

    open OUT, '>', $out or die $!;
    binmode(OUT);

    $/ = (defined $start_pos) ? \$start_pos : undef;
    $fh->seek(0, 0);
    print OUT scalar $fh->getline;
    $/ = undef;

    my $data_len = 0;
    if (!defined $start_pos and $bundle) {
	require PAR;
	PAR::_init_dynaloader();

	eval { require PerlIO::scalar; 1 }
	    or eval { require IO::Scalar; 1 }
	    or die "Cannot require either PerlIO::scalar nor IO::Scalar!";

	require IO::File;
	require Compress::Zlib;
	require Archive::Zip;

	foreach (sort keys %::) {
	    $::{$_} =~ /_<(.*)(\bauto\/.*\.$Config::Config{dlext})$/ or next;

	    $data_len += 12 + length($2) + (stat($1.$2))[7];

	    print OUT "FILE";
	    print OUT pack('N', length($2));
	    print OUT $2;
	    print OUT pack('N', (stat($1.$2))[7]);

	    open FILE, $1.$2 or die $!;
	    print OUT <FILE>;
	    close FILE;
	}
    }

    print OUT "PK\003\004";
    print OUT <PAR>;
    print OUT pack('N', $data_len + (stat($par))[7]);
    print OUT "\nPAR.pm\n";

    chmod 0755, $out;
    exit;
}

{
    last unless defined $start_pos;

    my $seek_ref  = $fh->can('seek');
    my $tell_ref  = $fh->can('tell');

    no strict 'refs';
    *{'IO::File::seek'} = sub {
	my ($fh, $pos, $whence) = @_;
	$pos += $start_pos if $whence == 0;
	$seek_ref->($fh, $pos, $whence);
    };
    *{'IO::File::tell'} = sub {
	return $tell_ref->(@_) - $start_pos;
    };

    require PAR;
    PAR::_init_dynaloader();
    require Archive::Zip;

    my $zip = Archive::Zip->new;
    $zip->readFromFileHandle($fh) == Archive::Zip::AZ_OK() or last;

    push @PAR::LibCache, $zip;
    $PAR::LibCache{$0} = $zip;
}

unless ($PAR::LibCache{$0}) {
    die << "." unless @ARGV;
Usage: $0 [-Alib.par] [-Idir] [-Mmodule] [src.par] program.pl
       $0 [-Ooutfile] src.par
.
    $0 = shift(@ARGV)
}

########################################################################
# The main package for script execution

package main;

require PAR;
PAR->import(@par_args);

die qq(Can't open perl script "$0": No such file or directory\n)
    unless -e $0;

do $0;
die $@ if $@;
exit;

=head1 SEE ALSO

L<PAR>, L<perlcc>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

__END__
