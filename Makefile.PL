#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #28 $ $Change: 4501 $ $DateTime: 2003/03/01 15:02:18 $

use 5.006;
use lib 'inc';
use Config;
use File::Spec;
use Module::Install;

check_nmake();

my $have_cc = can_run($Config{cc});
my $exe	    = $Config{_exe};

warn "No compiler found, won't generate 'script/par$Config$exe'!\n"
    unless $have_cc;

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive Tookit',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',
    MAN1PODS		=> {
	'script/par.pl'	    => 'blib/man1/par.pl.1',
	'script/pp'	    => 'blib/man1/pp.1',
      $have_cc ? (
	'script/parl.pod'   => 'blib/man1/parl.1',
      ) : (),
    },
    EXE_FILES		=> [
	'script/par.pl',
	'script/pp',
      $have_cc ? (
	"script/parl$exe",
      ) : (),
    ],
    NEEDS_LINKING	=> 1,

    PREREQ_PM		=> {
	'Archive::Zip'	    => 1.0,
	'IO::File'	    => 0,
	'File::Temp'	    => 0,
	'Module::ScanDeps'  => 0.17,
    },

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);

sub MY::postamble {
    return "" unless $have_cc;

    my $par_exe  = File::Spec->catfile( 'script', "par$exe" );
    my $parl_exe = File::Spec->catfile( 'script', "parl$exe" );

    return << "EOT";

all :: subdirs

clean ::
	\$(RM_RF) $par_exe
	\$(RM_RF) $parl_exe

ppm :: all
	tar cvf PAR.tar blib
	gzip -9 PAR.tar

EOT
}
