# $File: //depot/cpan/Module-Install/lib/Module/Install/AutoInstall.pm $ $Author: autrijus $
# $Revision: #8 $ $Change: 1328 $ $DateTime: 2003/03/08 13:42:14 $ vim: expandtab shiftwidth=4

package Module::Install::AutoInstall;
use base 'Module::Install::Base';

sub auto_install {
    my $self = shift;
    return if $self->{done}++;

# ExtUtils::AutoInstall Bootstrap Code, version 6.
AUTO:{my$p='ExtUtils::AutoInstall';my$v=0.45;$p->VERSION||0>=$v
or+eval"use $p $v;1"or+do{my$e=$ENV{PERL_EXTUTILS_AUTOINSTALL};
(!defined($e)||$e!~m/--(?:default|skip|testonly)/and-t STDIN or
eval"use ExtUtils::MakeMaker;WriteMakefile(PREREQ_PM=>{'$p',$v}
);1"and exit)and print"==> $p $v required. Install it from CP".
"AN? [Y/n] "and<STDIN>!~/^n/i and print"*** Installing $p\n"and
do{eval{require CPANPLUS;CPANPLUS::install $p};eval("use $p $v;
1")||eval{require CPAN;CPAN::install$p};eval"use $p $v;1"or die
"*** Please manually install $p $v from cpan.org first...\n"}}}

    # Flatten array of arrays into a single array
    my @core = map @$_, map @$_, grep ref, map $self->$_,
               qw(build_requires requires);

    ExtUtils::AutoInstall->import(
        (@core ? (-core => \@core) : ()), @_, $self->features
    );
    $self->makemaker_args( ExtUtils::AutoInstall::_make_args() );
    $self->postamble( ExtUtils::AutoInstall::postamble() );
}

sub auto_install_now {
    my $self = shift;
    $self->auto_install;
    ExtUtils::AutoInstall::do_install();
}

1;
