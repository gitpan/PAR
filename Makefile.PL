#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #20 $ $Change: 2574 $ $DateTime: 2002/12/03 00:27:26 $

use 5.006;
use Config;
use File::Spec;
use ExtUtils::MakeMaker;

check_nmake();

my $have_cc  = _can_run($Config{cc});
warn "No compiler found, won't generate 'script/par$Config{_exe}'!\n"
    unless $have_cc;

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive Tookit',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',
    EXE_FILES		=> [
	'script/par.pl',
	'script/pp',
	$have_cc ? ("script/par$Config{_exe}") : (),
    ],
    NEEDS_LINKING	=> 1,

    PREREQ_PM		=> {
	'Archive::Zip'	    => 1.0,
	'IO::File'	    => 0,
	'File::Temp'	    => 0,
	'Module::ScanDeps'  => 0.10,
    },

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);

sub MY::postamble {
    return "" unless $have_cc;

    my $script = File::Spec->catfile( 'script', "par$Config{_exe}" );

    return << "EOT";

all :: subdirs

clean ::
	\$(RM_RF) $script

ppm :: all
	tar cvf PAR.tar blib
	gzip -9 PAR.tar

EOT
}

# check if we can run some command
sub _can_run {
    my $command = shift;

    # absoluate pathname?
    return $command if (-x $command or $command = MM->maybe_command($command));

    for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
        my $abs = File::Spec->catfile($dir, $command);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

# determine if the user needs nmake, and download it if needed
sub check_nmake {
    return unless (
        $Config{make} =~ /^nmake\b/i and
        $^O eq 'MSWin32'             and
        !_can_run('nmake')
    );

    print "The required 'nmake' executable not found, fetching it...\n";

    use File::Basename;
    my $rv = get_file(
	url	    => 'ftp://ftp.microsoft.com/Softlib/MSLFILES/nmake15.exe',
	local_dir   => dirname($^X),
	size	    => 51928,
	run	    => 'nmake15.exe /o > nul',
	check_for   => 'nmake.exe',
	remove	    => 1,
    );

    if (!$rv) {
	die << '.';

========================================================================

Since you are using Microsoft Windows, you will need the 'nmake' utility
before installation. It's available at:

    ftp://ftp.microsoft.com/Softlib/MSLFILES/nmake15.exe

Please download the file manually, save it to a directory in %PATH (e.g.
C:\WINDOWS\COMMAND), then launch the MS-DOS command line shell, "cd" to
that directory, and run "nmake15.exe" from there; that will create the
'nmake.exe' file needed by this module.

You may then resume the installation process described in README.

========================================================================
.
    }
}

# fetch nmake from Microsoft's FTP site
sub get_file {
    my %args = @_;

    my ($scheme, $host, $path, $file) = 
	$args{url} =~ m|^(\w+)://([^/]+)(.+)/(.+)| or return;

    return unless $scheme eq 'ftp';

    unless (eval { require Socket; Socket::inet_aton($host) }) {
        print "Cannot fetch 'nmake'; '$host' resolve failed!\n";
        return;
    }

    use Cwd;
    my $dir = getcwd;
    chdir $args{local_dir} or return if exists $args{local_dir};

    $|++;
    print "Fetching '$file' from $host. It may take a few minutes... ";

    if (eval { require Net::FTP; 1 }) {
        # use Net::FTP to get pass firewall
        my $ftp = Net::FTP->new($host, Passive => 1, Timeout => 600);
        $ftp->login("anonymous", 'anonymous@example.com');
        $ftp->cwd($path);
        $ftp->binary;
        $ftp->get($file) or die $!;
        $ftp->quit;
    }
    elsif (_can_run('ftp')) {
        # no Net::FTP, fallback to ftp.exe
        require FileHandle;
        my $fh = FileHandle->new;

        local $SIG{CHLD} = 'IGNORE';
        unless ($fh->open("|ftp.exe -n")) {
            warn "Couldn't open ftp: $!";
            chdir $dir; return;
        }

        my @dialog = split(/\n/, << ".");
open $host
user anonymous anonymous\@example.com
cd $path
binary
get $file $file
quit
.
        foreach (@dialog) { $fh->print("$_\n") }
        $fh->close;
    }
    else {
        print "Cannot fetch '$file' without a working 'ftp' executable!\n";
        chdir $dir; return;
    }

    return if exists $args{size} and -s $file != $args{size};
    system($args{run}) if exists $args{run};
    unlink($file) if $args{remove};

    print (((!exists $args{check_for} or -e $args{check_for})
	? "done!" : "failed! ($!)"), "\n");
    chdir $dir; return !$?;
}

