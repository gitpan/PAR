#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #14 $ $Change: 1985 $ $DateTime: 2002/11/05 14:10:43 $

use 5.006;
use Config;
use File::Spec;
use ExtUtils::MakeMaker;

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
	'script/makepar.pl',
	$have_cc ? ("script/par$Config{_exe}") : (),
    ],
    NEEDS_LINKING	=> 0,

    PREREQ_PM		=> {
	'Archive::Zip'	    => 1.0,
	'IO::File'	    => 0,
	'File::Temp'	    => 0,
	'Module::ScanDeps'  => 0.02,
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

    for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
        my $abs = File::Spec->catfile($dir, $command);
        return $abs if $abs = MM->maybe_command($abs);
    }

    return;
}
