#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #45 $ $Change: 8195 $ $DateTime: 2003/09/20 20:37:54 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');
requires    ('File::Temp');
requires    ('Compress::Zlib'	=> 1.14);
requires    ('Archive::Zip'	=> 1.00);
requires    ('Module::ScanDeps'	=> 0.30);
requires    ('PAR::Dist'	=> 0.05);
features    (
    'Digital signature support'	=> [
	-default => 0,
	recommends  ('Module::Signature' => 0.35),
    ],
) if eval { require Crypt::OpenPGP; 1 } or can_run('gpg');

include	    ('ExtUtils::AutoInstall');
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
&Autrijus->fix;
