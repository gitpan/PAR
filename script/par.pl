#!/usr/bin/perl
# $File: //member/autrijus/PAR/script/par.pl $ $Author: autrijus $
# $Revision: #23 $ $Change: 2041 $ $DateTime: 2002/11/07 14:20:27 $

package __par_pl;

# --- This script cannot use any modules at compile time ---
# use strict;

=head1 NAME

par.pl - Make and Run Perl Archives

=head1 SYNOPSIS

To use F<Hello.pm> from F<./foo.par>:

    % par.pl -A./foo.par -MHello 
    % par.pl -A./foo -MHello	# the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello 
    % par.pl -Ifoo -MHello 	# ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl	# only when $ARGV[0] ends in '.par'
    % par.pl foo.par		# looks for 'main.pl' by default

To make a self-containing script containing a PAR file :

    % par.pl -O./foo.pl foo.par
    % ./foo.pl test.pl		# same as above

To embed the necessary non-core modules and shared objects for PAR's
execution (like C<Zlib>, C<IO>, C<Cwd>, etc), use the B<-b> flag:

    % par.pl -b -O./foo.pl foo.par
    % ./foo.pl test.pl		# runs anywhere with core modules installed

If you also wish to embed I<core> modules along, use the B<-B> flag
instead:

    % par.pl -B -O./foo.pl foo.par
    % ./foo.pl test.pl		# runs anywhere with the perl interpreter

This is particularly useful when making stand-alone binary
executables; see L<makepar.pl> for details.

=head1 DESCRIPTION

This stand-alone command offers roughly the same feature as C<perl
-MPAR>, except that it takes the pre-loaded F<.par> files via
C<-Afoo.par> instead of C<-MPAR=foo.par>.

If you have a C compiler, a binary version of B<par.pl> will also be
automatically installed.  You can use it to run F<.par> files:

    # runs script/run.pl in archive, uses its lib/* as libraries
    % par.exe myapp.par run.pl	# runs run.pl or script/run.pl in myapp.par

However, if the F<.par> archive contains either F<main.pl> or
F<script/main.pl>, it is used instead:

    % par.exe myapp.par run.pl	# runs main.pl, with 'run.pl' as @ARGV

Finally, as an alternative to C<Perl2exe> or C<PerlApp>, the C<-O>
option makes a stand-alone binary from a PAR file:

    % par.exe -B -Omyapp myapp.par
    % ./myapp			# run it anywhere without perl binaries
    % ./myapp -Omyap2 myapp.par	# makes a ./myap2, identical to ./myapp
    % ./myapp -Omyap3 myap3.par	# makes another app with different PAR

The format for the stand-alone executable is simply concatenating the
following elements:

=over 4

=item * The executable itself

Either in plain-text (F<par.pl>) or native executable format (F<par>
or F<par.exe>).

=item * Any number of embedded files

These are typically used for bootstrapping PAR's various XS dependencies.
Each section begins with the magic string "C<FILE>", length of file name
in C<pack('N')> format, file name (F<auto/.../>), file length in
C<pack('N')>, and the file's content (not compressed).

=item * One PAR file

This is just a zip file beginning with the magic string "C<PK\003\004>".

=item * Ending section

A pack('N') number of the total length of FILE and PAR sections,
followed by a 8-bytes magic string: "C<\012PAR.pm\012>".

=back

=head1 NOTES

If your system has a C compiler, the stand-alone binary version of
par.pl will be compiled and installed automatically.  You can generate
self-executable binaries by:

    # put a main.pl inside myapp.par to run it automatically
    % par -O./myapp myapp.par

The C<-B> flag described earlier is particularly useful here,
to build a truly self-containing executable:

    # bundle all needed shared objects (or F<.dll>s)
    % par -B -O./myapp myapp.par

=cut

# Argument processing {{{
my @par_args;
my ($out, $bundle, $quiet);

while (@ARGV) {
    $ARGV[0] =~ /^-([AIMOBbq])(.*)/ or last;

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
    elsif ($1 eq 'b') {
	$bundle = 'site';
    }
    elsif ($1 eq 'B') {
	$bundle = 'all';
    }
    elsif ($1 eq 'q') {
	$quiet = 1;
    }

    shift(@ARGV);
}

# fix $0 if invoked from PATH
unless (-f $0) {
    $Config{path_sep} = ($^O =~ /^MSWin/ ? ';' : ':');
    $Config{_exe} = ($^O =~ /^MSWin|OS2/ ? '.exe' : '');
    $Config{_delim} = ($^O =~ /^MSWin|OS2/ ? '\\' : '/');
    if (-f "$0$Config{_exe}") {
        $0 = "$0$Config{_exe}";
    }
    else {
        foreach my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
	    (($0 = "$dir$Config{_delim}$0$Config{_exe}"), last)
		if -f "$dir$Config{_delim}$0$Config{_exe}";
	    (($0 = "$dir$Config{_delim}$0"), last)
		if -f "$dir$Config{_delim}$0";
	}
    }
}

# }}}

# Magic string checking and extracting bundled modules {{{
my ($start_pos, $data_pos);
{
    # Check file type, get start of data section {{{
    open _FH, $0 or last;
    binmode(_FH);

    my $buf;
    seek _FH, -8, 2;
    read _FH, $buf, 8;
    last unless $buf eq "\nPAR.pm\n";

    seek _FH, -12, 2;
    read _FH, $buf, 4;
    seek _FH, -12 - unpack("N", $buf), 2;
    read _FH, $buf, 4;

    $data_pos = (tell _FH) - 4;
    # }}}

    # Extracting each file into memory {{{
    my %require_list;
    while ($buf eq "FILE") {
	read _FH, $buf, 4;
	read _FH, $buf, unpack("N", $buf);

	my $fullname = $buf;
	my ($basename, $ext) = ($buf =~ m|(?:.*/)?(.*)(\..*)|);

	read _FH, $buf, 4;
	read _FH, $buf, unpack("N", $buf);

	if (defined($ext) and $ext !~ /\.(?:pm|ix|al)$/i) {
	    my ($out, $filename) = _tempfile($ext);
	    print $out $buf;
	    close $out;
	    $PAR::Heavy::DLCache{$filename}++;
	    $PAR::Heavy::DLCache{$basename} = $filename;
	}
	else {
	    $require_list{$fullname} = \"$buf";
	}
	read _FH, $buf, 4;
    }
    # }}}

    local @INC = (sub {
	my ($self, $module) = @_;

	return if ref $module or !$module;

	my $filename = delete $require_list{$module} || do {
	    my $key;
	    foreach (keys %require_list) {
		next unless /\Q$module\E$/;
		$key = $_; last;
	    }
	    delete $require_list{$key};
	} or return;

	if (defined(&IO::File::new)) {
	    my $fh = IO::File->new_tmpfile or die $!;
	    print $fh $$filename;
	    seek($fh, 0, 0);
	    return $fh;
	}
	else {
	    my ($out, $name) = _tempfile($ext);
	    print $out $$filename;
	    close $out;
	    open my $fh, $name or die $!;
	    return $fh;
	}

	die "Bootstrapping failed: cannot find $module!\n";
    }, @INC);
    # }}}

    # Now load all bundled files {{{

    # initialize shared object processing
    require XSLoader;
    require PAR::Heavy;
    PAR::Heavy::_init_dynaloader();

    # now let's try getting helper modules from within
    require IO::File;

    # load rest of the group in
    while (my $filename = (sort keys %require_list)[0]) {
	require $filename unless $INC{$filename} or $filename =~ /BSDPAN/;
	delete $require_list{$filename};
    }

    # }}}

    last unless $buf eq "PK\003\004";
    $start_pos = (tell _FH) - 4;
}
# }}}

# Output mode (-O) handling {{{
if ($out) {
    my $par = shift(@ARGV);

    # Open input and output files {{{
    open PAR, '<', $par or die "$!: $par";
    binmode(PAR);

    local $/ = \4;
    die "$par is not a PAR file" unless <PAR> eq "PK\003\004";

    open OUT, '>', $out or die $!;
    binmode(OUT);

    $/ = (defined $start_pos) ? \$start_pos : undef;
    seek _FH, 0, 0;
    print OUT scalar <_FH>;
    $/ = undef;
    # }}}

    # Write bundled modules {{{
    my $data_len = 0;
    if (!defined $start_pos and $bundle) {
	require PAR::Heavy;
	PAR::Heavy::_init_dynaloader();
	require_modules();

	my @inc = sort {
	    length($b) <=> length($a)
	} grep {
	    !/BSDPAN/
	} grep {
	    ($bundle ne 'site') or 
	    ($_ ne $Config::Config{archlibexp} and
	     $_ ne $Config::Config{privlibexp});
	} @INC;

	foreach (sort keys %::) {
	    my ($path, $file);
	    foreach my $dir (@inc) {
		$::{$_} =~ /_<(\Q$dir\E\/)(.*[^Cc])$/ or next;
		($path, $file) = ($1, $2);
		last;
	    }

	    next unless defined $file;
	    print "$path$file\n" unless $quiet;
	    open FILE, "$path$file" or die "$file$path: $!";
	    binmode(FILE);

	    print OUT "FILE";
	    print OUT pack('N', length($file));
	    print OUT $file;
	    print OUT pack('N', (stat("$path$file"))[7]);

	    print OUT <FILE>;
	    close FILE;

	    $data_len += 12 + length($file) + (stat("$path$file"))[7];
	}
    }
    # }}}

    # Now write out the PAR and magic strings {{{
    print OUT "PK\003\004";
    print OUT <PAR>;
    print OUT pack('N', $data_len + (stat($par))[7]);
    print OUT "\nPAR.pm\n";
    close OUT;
    chmod 0755, $out;
    # }}}

    exit;
}
# }}}

# Prepare $0 into PAR file cache {{{
{
    last unless defined $start_pos;

    # Set up fake IO::File routines to point into the PAR subfile {{{
    require IO::File;
    my $fh = IO::File->new($0);
    my $seek_ref  = $fh->can('seek');
    my $tell_ref  = $fh->can('tell');

    *{'IO::File::seek'} = sub {
	# return $seek_ref->(@_) unless $PAR::__reading;
	my ($fh, $pos, $whence) = @_;
	$pos += $start_pos if $whence == 0;
	$seek_ref->($fh, $pos, $whence);
    };
    *{'IO::File::tell'} = sub {
	# return $tell_ref->(@_) unless $PAR::__reading;
	return $tell_ref->(@_) - $start_pos;
    };
    # }}}

    # Now load the PAR file and put it into PAR::LibCache {{{
    require PAR;
    PAR::Heavy::_init_dynaloader();
    require Archive::Zip;

    local $PAR::__reading = 1;
    my $zip = Archive::Zip->new;
    $zip->readFromFileHandle($fh) == Archive::Zip::AZ_OK() or die "$!: $@";

    push @PAR::LibCache, $zip;
    $PAR::LibCache{$0} = $zip;
    # }}}
}
# }}}

# If there's no main.pl to run, show usage {{{
unless ($PAR::LibCache{$0}) {
    die << "." unless @ARGV;
Usage: $0 [ -Alib.par ] [ -Idir ] [ -Mmodule ] [ src.par ] [ program.pl ]
       $0 [ -B|-b ] [-Ooutfile] src.par
.
    $0 = shift(@ARGV)
}
# }}}

sub require_modules {
    require integer;
    require strict;
    require warnings;
    require vars;
    require Carp;
    require Carp::Heavy;
    require Exporter::Heavy;
    require Exporter;
    require Fcntl;
    require Cwd;
    require File::Temp;
    require File::Spec;
    require XSLoader;
    require Carp::Heavy;
    require Config;
    require IO::File;
    require Compress::Zlib;
    require Archive::Zip;
    require PAR;
}

my $tmpdir;
sub tmpdir {
    return $tmpdir if defined $tmpdir;
    my @dirlist = (@ENV{qw(TMPDIR TEMP TMP)}, qw(C:/temp /tmp /));
    {
        if (${"\cTAINT"}) { eval {
            require Scalar::Util;
            @dirlist = grep { ! Scalar::Util::tainted $_ } @dirlist;
        } }
    }
    foreach (@dirlist) {
        next unless defined && -d;
        $tmpdir = $_;
        last;
    }
    $tmpdir = '' unless defined $tmpdir;
    return $tmpdir;
}

my ($tmpfile, @tmpfiles);
sub _tempfile {
    my $ext = shift;
    
    if (defined &File::Temp::tempfile) {
	return File::Temp::tempfile(
	    SUFFIX	=> $ext,
	    UNLINK	=> 1
	);
    }
    else {
	my $file;
	my $tmpdir = tmpdir();
	$tmpfile ||= ($$ . '0000');
	do { $tmpfile++ } while -e ($file = "$tmpdir/$tmpfile$ext");
	push @tmpfiles, $file;
	open my $fh, ">", $file or die $!;
	return ($fh, $file);
    }
}
END { unlink @tmpfiles if @tmpfiles }

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

L<PAR>, L<makepar.pl>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

__END__
