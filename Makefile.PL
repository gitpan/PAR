#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #34 $ $Change: 4808 $ $DateTime: 2003/03/19 14:12:06 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');
requires    ('File::Temp');
requires    ('Compress::Zlib' => 1.14);
requires    ('Archive::Zip' => 1.0);
requires    ('Module::ScanDeps' => 0.17);

include	    ('ExtUtils::AutoInstall');
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
&Autrijus->fix;
