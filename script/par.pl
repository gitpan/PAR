#!/usr/bin/perl

package __par_pl;

use strict;
use PAR ((
    eval { require PerlIO::scalar; 1 } or
    eval { require IO::Scalar; 1 } or
    1
) ? () : ());
use IO::File;
use Archive::Zip;

=head1 NAME

par.pl - Run Perl Archives

=head1 SYNOPSIS

To use F<Hello.pm>, F<lib/Hello.pm> or F<lib/arch/Hello.pm> from
F<./foo.par>:

    % par.pl -A./foo.par -MHello 
    % par.pl -A./foo -MHello	# the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello 
    % par.pl -Ifoo -MHello 	# ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl	# only when $ARGV[0] ends in '.par'
    % par.pl foo.par		# looks for 'main.pl' by default

You can also make a self-reading script containing a PAR file :

    % par.pl -O./foo.pl foo.par
    % ./foo.pl test.pl		# same as above

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
    % par myapp.par		# runs main.pl or script/main.pl by default

Finally, as an alternative to C<perl2exe> or C<PerlApp>, the C<-o>
option makes a stand-alone binary from a PAR file:

    % par -Omyapp myapp.par	# makes a stand-alone executable
    % ./myapp run.pl		# same as above
    % ./myapp -Omyap2 myapp.par	# makes a ./myap2, identical to ./myapp
    % ./myapp -Omyap3 myap3.par	# makes another app with different PAR

The format for sthe tand-alone executable is simply concatenating the
PAR file after F<par> or F<par.pl>, followed by the PAR file's length,
packed in 4 bytes as an unsigned long number, in network order (i.e.
C<pack('N')>).

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

=cut

my @par_args;
my $out;

while (@ARGV) {
    $ARGV[0] =~ /^-([AIMO])(.*)/ or last;

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

    shift(@ARGV);
}

die << "." unless @ARGV;
Usage: $0 [-Alib.par] [-Idir] [-Mmodule] [src.par] program.pl
       $0 [-Ooutfile] src.par
.

my $fh;
my $start_pos;

{
    $fh = IO::File->new;
    binmode($fh);
    last unless $fh->open($0);

    my $buf;
    $fh->seek(-1, 2);
    $fh->read($buf, 1);
    last unless $buf eq "\n";
    $fh->seek(-5, 2);
    $fh->read($buf, 4);
    $fh->seek(-5 - unpack("N", $buf), 2);
    $fh->read($buf, 4);
    last unless $buf eq "PK\003\004";
    
    $start_pos = $fh->tell - 4;
}

if ($out) {
    my $par = shift(@ARGV);

    open PAR, '<', $par or die $!;
    open OUT, '>', $out or die $!;

    binmode(PAR);
    binmode(OUT);

    local $/;

    $/ = \$start_pos if defined $start_pos;
    $fh->seek(0, 0);
    print OUT scalar $fh->getline;
    $/ = undef;

    print OUT <PAR>;
    print OUT pack('N', (stat($par))[7]);
    print OUT "\n";

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

    my $zip = Archive::Zip->new;
    $zip->readFromFileHandle($fh) == Archive::Zip::AZ_OK() or last;

    push @PAR::LibCache, $zip;
    $PAR::LibCache{$0} = $zip;
}

$0 = shift(@ARGV) unless $PAR::LibCache{$0};

package main;

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
