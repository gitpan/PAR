#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #52 $ $Change: 9460 $ $DateTime: 2003/12/28 02:00:30 $

use 5.006;
use inc::Module::Install;

name	    ('PAR');
abstract    ('Perl Archive Tookit');
version_from('lib/PAR.pm');
license	    ('perl');

requires    ('File::Temp');
requires    ('Compress::Zlib'	=> ($^O eq 'MSWin32') ? 1.16 : 1.30);
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
