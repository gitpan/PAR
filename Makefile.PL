#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #5 $ $Change: 1537 $ $DateTime: 2002/10/19 14:18:37 $

use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',
    EXE_FILES		=> [ 'script/par.pl' ],

    PREREQ_PM		=> {
	'Archive::Zip'	=> 0,
(eval { require PerlIO::scalar; 1}) ? () : (
	'PerlIO::Scalar'=> 0,
),
    },

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);
