#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #30 $ $Change: 4655 $ $DateTime: 2003/03/08 19:09:16 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('PAR.pm');
requires    ('Archive::Zip' => 1.0);
requires    ('Module::ScanDeps' => 0.17);

include	    ('ExtUtils::AutoInstall');
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
