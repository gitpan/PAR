#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #2 $ $Change: 1514 $ $DateTime: 2002/10/18 20:49:57 $

use 5.006;
use ExtUtils::MakeMaker;

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',

    PREREQ_PM		=> {
	'Archive::Zip'	=> 0,
    },

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);
