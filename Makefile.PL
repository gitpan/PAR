#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #38 $ $Change: 7148 $ $DateTime: 2003/07/27 07:21:03 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');
requires    ('File::Temp');
requires    ('Compress::Zlib' => 1.14);
requires    ('Archive::Zip' => 1.0);
requires    ('Module::ScanDeps' => 0.19);
requires    ('PAR::Dist' => 0.03);
features    (
    'Digital signature support'	=> [
	-default => 0,
	recommends  ('Module::Signature' => 0.25),
    ],
);

include	    ('ExtUtils::AutoInstall');
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
&Autrijus->fix;
