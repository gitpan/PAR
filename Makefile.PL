#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #49 $ $Change: 8611 $ $DateTime: 2003/10/29 03:25:28 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');

requires    ('File::Temp');
requires    ('Compress::Zlib'	=> 1.30);
requires    ('Archive::Zip'	=> 1.00);
requires    ('Module::ScanDeps'	=> 0.32);
requires    ('PAR::Dist'	=> 0.05);
features    (
    'Digital signature support'	=> [
	-default => 0,
	recommends  ('Digest::SHA1' => 0),
	recommends  ('Module::Signature' => 0.35),
    ],
) if eval { require Crypt::OpenPGP; 1 } or can_run('gpg');

include('ExtUtils::AutoInstall');

sign(1);
check_nmake();
auto_install();

&Meta->write;
&Autrijus->write;
&Makefile->write;
&Autrijus->fix;
