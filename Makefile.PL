#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #11 $ $Change: 1841 $ $DateTime: 2002/11/02 20:33:29 $

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
	'File::Temp'	    => 0,
	'Module::ScanDeps'  => 0.02,
(($^O ne 'MSWin32') and eval { require PerlIO::scalar; 1}) ? () : (
	'IO::Scalar'	    => 0,
),
    },

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);
