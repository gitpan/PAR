#!/usr/bin/perl
# $File: //member/autrijus/PAR/script/par.pl $ $Author: autrijus $
# $Revision: #47 $ $Change: 4749 $ $DateTime: 2003/03/17 01:06:47 $ vim: expandtab shiftwidth=4

package __par_pl;

# --- This script must not use any modules at compile time ---
#use strict;

=head1 NAME

par.pl - Make and run Perl Archives

=head1 SYNOPSIS

(Please see L<pp> for convenient ways to make self-contained
executables, scripts or PAR archives from perl programs.)

To use F<Hello.pm> from F<./foo.par>:

    % par.pl -A./foo.par -MHello 
    % par.pl -A./foo -MHello    # the .par part is optional

Same thing, but search F<foo.par> in the F<@INC>;

    % par.pl -Ifoo.par -MHello 
    % par.pl -Ifoo -MHello      # ditto

Run F<test.pl> or F<script/test.pl> from F<foo.par>:

    % par.pl foo.par test.pl    # looks for 'main.pl' by default,
                                # otherwise run 'test.pl' 

To make a self-containing script containing a PAR file :

    % par.pl -O./foo.pl foo.par
    % ./foo.pl test.pl          # same as above

To embed the necessary non-core modules and shared objects for PAR's
execution (like C<Zlib>, C<IO>, C<Cwd>, etc), use the B<-b> flag:

    % par.pl -b -O./foo.pl foo.par
    % ./foo.pl test.pl          # runs anywhere with core modules installed

If you also wish to embed I<core> modules along, use the B<-B> flag
instead:

    % par.pl -B -O./foo.pl foo.par
    % ./foo.pl test.pl          # runs anywhere with the perl interpreter

This is particularly useful when making stand-alone binary
executables; see L<pp> for details.

=head1 DESCRIPTION

This stand-alone command offers roughly the same feature as C<perl
-MPAR>, except that it takes the pre-loaded F<.par> files via
C<-Afoo.par> instead of C<-MPAR=foo.par>.

=head2 Binary PAR loader (L<parl>)

If you have a C compiler, or a pre-built binary package of B<PAR> is
available for your platform, a binary version of B<par.pl> will also be
automatically installed as B<parl>.  You can use it to run F<.par> files:

    # runs script/run.pl in archive, uses its lib/* as libraries
    % parl myapp.par run.pl     # runs run.pl or script/run.pl in myapp.par
    % parl otherapp.pl          # also runs normal perl scripts

However, if the F<.par> archive contains either F<main.pl> or
F<script/main.pl>, it is used instead:

    % parl myapp.par run.pl     # runs main.pl, with 'run.pl' as @ARGV

Finally, the C<-O> option makes a stand-alone binary executable from a
PAR file:

    % parl -B -Omyapp myapp.par
    % ./myapp                   # run it anywhere without perl binaries

With the C<--par-options> flag, generated binaries can act as C<parl>
to pack new binaries: 

    % ./myapp --par-options -Omyap2 myapp.par   # identical to ./myapp
    % ./myapp --par-options -Omyap3 myap3.par   # now with different PAR

=head2 Stand-alone executable format

The format for the stand-alone executable is simply concatenating the
following elements:

=over 4

=item * The executable itself

Either in plain-text (F<par.pl>) or native executable format (F<parl>
or F<parl.exe>).

=item * Any number of embedded files

These are typically used for bootstrapping PAR's various XS dependencies.
Each section contains:

=over 4

=item The magic string "C<FILE>"

=item Length of file name in C<pack('N')> format plus 9

=item 8 bytes of hex-encoded CRC32 of file content

=item A single slash ("C</>")

=item The file name (without path)

=item File length in C<pack('N')> format

=item The file's content (not compressed)

=back

=item * One PAR file

This is just a zip file beginning with the magic string "C<PK\003\004>".

=item * Ending section

A pack('N') number of the total length of FILE and PAR sections,
followed by a 8-bytes magic string: "C<\012PAR.pm\012>".

=back

=cut

my $quiet = !$ENV{PAR_DEBUG};

# fix $0 if invoked from PATH
unless (-f $0) {
    my %Config;
    $Config{path_sep} = ($^O =~ /^MSWin/ ? ';' : ':');
    $Config{_exe} = ($^O =~ /^MSWin|OS2/ ? '.exe' : '');
    $Config{_delim} = ($^O =~ /^MSWin|OS2/ ? '\\' : '/');

    if (-f "$0$Config{_exe}") {
        $0 = "$0$Config{_exe}";
    }
    else {
        foreach my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
            $dir =~ s/\Q$Config{_delim}\E$//;
            (($0 = "$dir$Config{_delim}$0$Config{_exe}"), last)
                if -f "$dir$Config{_delim}$0$Config{_exe}";
            (($0 = "$dir$Config{_delim}$0"), last)
                if -f "$dir$Config{_delim}$0";
        }
    }
}

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
        outs(qq(Unpacking file "$fullname"...));
        my $crc = ( $fullname =~ s|^([a-f\d]{8})/|| ) ? $1 : undef;
        my ($basename, $ext) = ($buf =~ m|(?:.*/)?(.*)(\..*)|);

        read _FH, $buf, 4;
        read _FH, $buf, unpack("N", $buf);

        if (defined($ext) and $ext !~ /\.(?:pm|ix|al)$/i) {
            my ($out, $filename) = _tempfile($ext, $crc);
            if ($out) {
                binmode($out);
                print $out $buf;
                close $out;
            }
            $PAR::Heavy::DLCache{$filename}++;
            $PAR::Heavy::DLCache{$basename}   =
            $PAR::Heavy::FullCache{$fullname} = $filename;
            $PAR::Heavy::FullCache{$filename} = $fullname;
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

        $INC{$module} = "/loader/$filename/$module";

        if (defined(&IO::File::new)) {
            my $fh = IO::File->new_tmpfile or die $!;
            binmode($fh);
            print $fh $$filename;
            seek($fh, 0, 0);
            return $fh;
        }
        else {
            my ($out, $name) = _tempfile('.pm');
            if ($out) {
                binmode($out);
                print $out $$filename;
                close $out;
            }
            open my $fh, $name or die $!;
            binmode($fh);
            return $fh;
        }

        die "Bootstrapping failed: cannot find $module!\n";
    }, @INC);
    # }}}

    # Now load all bundled files {{{

    # initialize shared object processing
    require XSLoader;
    require PAR::Heavy;
    require Carp::Heavy;
    require Exporter::Heavy;
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

# Argument processing {{{
my @par_args;
my ($out, $bundle);

$quiet = 0 unless $ENV{PAR_DEBUG};

# Don't swallow arguments for compiled executables without --par-options
if (!$start_pos or ($ARGV[0] eq '--par-options' && shift)) {
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
}

# }}}

# Output mode (-O) handling {{{
if ($out) {
    my $par = shift(@ARGV);

    # Open input and output files {{{
    local $/ = \4;

    if (defined $par) {
        open PAR, '<', $par or die "$!: $par";
        binmode(PAR);
        die "$par is not a PAR file" unless <PAR> eq "PK\003\004";
    }

    open OUT, '>', $out or die $!;
    binmode(OUT);

    $/ = (defined $data_pos) ? \$data_pos : undef;
    seek _FH, 0, 0;
    my $loader = scalar <_FH>;
    $loader =~ s/
        ^=(?:head\d|pod|begin|item|over|for|back|end)\b.*?
        ^=cut\s*$
        \n*
    //smgx if !$ENV{PAR_VERBATIM} and $loader =~ /^(?:#!|\@rem)/;
    print OUT $loader;
    $/ = undef;
    # }}}

    # Write bundled modules {{{
    my $data_len = 0;
    if ($bundle) {
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

        my %files;
        /^_<(.+)$/ and $files{$1}++ for keys %::;
        $files{$_}++ for values %INC;

        my $lib_ext = $Config::Config{lib_ext};

        foreach (sort keys %files) {
            my ($name, $file);

            foreach my $dir (@inc) {
                if ($name = $PAR::Heavy::FullCache{$_}) {
                    $file = $_;
                    last;
                }
                elsif (/^(\Q$dir\E\/(.*[^Cc]))\Z/) {
                    ($file, $name) = ($1, $2);
                    last;
                }
                elsif (m!^/loader/[^/]+/(.*[^Cc])\Z! and -f "$dir/$1") {
                    ($file, $name) = ("$dir/$1", $1);
                    last;
                }
            }

            next unless defined $name;
            next if ( $file =~ /\.\Q$lib_ext\E$/ );
            outs("Writing $file");

            open FILE, "$file" or die "Can't open $file: $!";
            binmode(FILE);
            my $content = <FILE>;
            $content =~ s/
                ^=(?:head\d|pod|begin|item|over|for|back|end)\b.*?
                ^=cut\s*$
                \n*
            //smgx if !$ENV{PAR_VERBATIM} and lc($name) =~ /\.(?:pm|ix|al)$/i;
            close FILE;

            outs(qq(Packing file "$name"...));
            print OUT "FILE";
            print OUT pack('N', length($name) + 9);
            print OUT sprintf(
                "%08x/%s", Archive::Zip::computeCRC32($content), $name
            );
            print OUT pack('N', length($content));
            print OUT $content;

            $data_len += 12 + length($name) + 9 + length($content);
        }
    }
    # }}}

    # Now write out the PAR and magic strings {{{
    if (defined($par)) {
        print OUT "PK\003\004";
        print OUT <PAR>;
        print OUT pack('N', $data_len + (stat($par))[7]);
    }
    else {
        print OUT pack('N', $data_len);
    }

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
        return $seek_ref->(@_) unless $PAR::__reading;
        my ($fh, $pos, $whence) = @_;
        $pos += $start_pos if $whence == 0;
        $seek_ref->($fh, $pos, $whence);
    };
    *{'IO::File::tell'} = sub {
        return $tell_ref->(@_) unless $PAR::__reading;
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
    require lib;
    require DynaLoader;
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
    require Config;
    require IO::File;
    require Compress::Zlib;
    require Archive::Zip;
    require PAR;
    require PAR::Heavy;
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
    my ($ext, $crc) = @_;
    my ($fh, $filename);
    
    if (defined $crc and !$ENV{PAR_CLEARTEMP}) {
        $filename = tmpdir() . "/$crc$ext";
        return (undef, $filename) if (-r $filename);

        open $fh, '>', $filename or die $!;
    }
    elsif (defined &File::Temp::tempfile) {
        # under Win32, the file is created with O_TEMPORARY,
        # and will be deleted by the C runtime; having File::Temp
        # delete it has the only effect of giving an ugly warnings
        ($fh, $filename) = File::Temp::tempfile(
            SUFFIX      => $ext,
            UNLINK      => ($^O ne 'MSWin32'),
        ) or die $!;
    }
    else {
        my $tmpdir = tmpdir();
        $tmpfile ||= ($$ . '0000');
        do { $tmpfile++ } while -e ($filename = "$tmpdir/$tmpfile$ext");
        push @tmpfiles, $filename;
        open $fh, ">", $filename or die $!;
    }

    binmode($fh);
    return ($fh, $filename);
}
END { unlink @tmpfiles if @tmpfiles }

sub outs { warn("@_\n") unless $quiet }

########################################################################
# The main package for script execution

package main;

require PAR;
unshift @INC, \&PAR::find_par;
PAR->import(@par_args);

die qq(Can't open perl script "$0": No such file or directory\n)
    unless -e $0;

do $0;
die $@ if $@;
exit;

=head1 SEE ALSO

L<PAR>, L<parl>, L<pp>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

PAR has a mailing list, E<lt>par@perl.orgE<gt>, that you can write to;
send an empty mail to E<lt>par-subscribe@perl.orgE<gt> to join the list
and participate in the discussion.

Please send bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2002, 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut

__END__
