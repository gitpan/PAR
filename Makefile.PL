#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #43 $ $Change: 7619 $ $DateTime: 2003/08/20 09:37:38 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');
requires    ('File::Temp');
requires    ('Compress::Zlib' => 1.14);
requires    ('Archive::Zip' => 1.0);
requires    ('Module::ScanDeps' => 0.28);
requires    ('PAR::Dist' => 0.05);
features    (
    'Digital signature support'	=> [
	-default => 0,
	recommends  ('Module::Signature' => 0.25),
    ],
) if eval { require Crypt::OpenPGP; 1 } or can_run('gpg');

include	    ('ExtUtils::AutoInstall');
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
&Autrijus->fix;
