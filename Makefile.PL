#!/usr/bin/perl
# $File: //member/autrijus/PAR/Makefile.PL $ $Author: autrijus $
# $Revision: #1 $ $Change: 1512 $ $DateTime: 2002/10/18 20:23:57 $

use 5.006;
use Config;

# ExtUtils::AutoInstall Bootstrap Code, version 4.
BEGIN{my$p='ExtUtils::AutoInstall';my$v=.21;eval"use $p $v;1"or
($ENV{PERL_EXTUTILS_AUTOINSTALL}!~/--(?:default|skip|testonly)/
and(-t STDIN)or eval"use ExtUtils::MakeMaker;WriteMakefile('PR'
.'EREQ_PM'=>{'$p',$v});1"and exit)and print"==> $p $v needed. "
."Install it from CPAN? [Y/n] "and<STDIN>!~/^n/i and print"***"
." Fetching $p\n"and do{eval{require CPANPLUS;CPANPLUS::install
$p};eval"use $p $v;1"or eval{require CPAN;CPAN::install$p};eval
"use $p $v;1"or die"Please install $p $v manually first...\n"}}

ExtUtils::AutoInstall->import(
    -core			=> [
	'Archive::Zip'		=> 0,
    ],
    'Run scripts in .PAR files'	=> [
	-default		=> _can_run($Config::Config{cc}),
        'IO::Scalar'		=> 0,
        'Filter::Util::Call'	=> 0,
        'Filter::Simple'	=> 0,
    ],
);

WriteMakefile(
    AUTHOR		=> 'Autrijus Tang (autrijus@autrijus.org)',
    ABSTRACT		=> 'Perl Archive',
    NAME		=> 'PAR',
    VERSION_FROM	=> 'PAR.pm', 
    DISTNAME		=> 'PAR',
    BINARY_LOCATION	=> 'x86/PAR.tar.gz',

    dist		=> {
        COMPRESS	=> 'gzip -9',
        SUFFIX		=> '.gz',
    },
);

# check if we can run some command
sub _can_run {
    my $command = shift;

    for my $dir (split /$Config{path_sep}/, $ENV{PATH}) {
        my $abs = File::Spec->catfile($dir, $command);
        return $abs if $abs = MM->maybe_command($abs);
    }

    return;
}

