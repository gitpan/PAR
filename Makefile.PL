#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #12 $ $Change: 1855 $ $DateTime: 2002/11/03 12:41:13 $

use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',
    EXE_FILES		=> [ 'script/par.pl', 'script/makepar.pl' ],

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
