# $File: //depot/cpan/Module-Install/lib/Module/Install/Makefile.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1187 $ $DateTime: 2003/03/01 04:31:52 $

package Module::Install::Makefile;
$VERSION = '0.01';

use strict 'vars';
use vars '$VERSION';

use ExtUtils::MakeMaker ();

sub prompt { goto &ExtUtils::MakeMaker::prompt }

sub WriteMakefile {
    my ($self, %args) = @_;
    my $ARGS = {};
    $self->{args} = $ARGS;

    foreach my $var (qw(NAME VERSION)) {
	$ARGS->{$var} = $args{$var}	if defined $args{$var};
	$ARGS->{$var} = ${"main::$var"}	if defined ${"main::$var"};
	my $method = "determine_$var";
	$ARGS->{$var} = $self->$method($ARGS)
	    unless defined $ARGS->{$var} or defined $ARGS->{"${var}_FROM"};
    }

    $self->determine_CLEAN_FILES($ARGS)
	if defined $main::CLEAN_FILES or defined @main::CLEAN_FILES;

    if ($] >= 5.005) {
	$ARGS->{ABSTRACT}   = $main::ABSTRACT	if defined $main::ABSTRACT;
	$ARGS->{AUTHOR}	    = $main::AUTHOR	if defined $main::AUTHOR;
    }
    $ARGS->{PREREQ_PM}	= \%main::PREREQ_PM	if defined %main::PREREQ_PM;
    $ARGS->{PL_FILES}	= \%main::PL_FILES	if defined %main::PL_FILES;
    $ARGS->{EXE_FILES}	= \@main::EXE_FILES	if defined @main::EXE_FILES;

    ExtUtils::MakeMaker::WriteMakefile(%$ARGS, %args);

    $self->call('update_manifest');
    fix_up_makefile();
}

sub find_files {
    my ($self, $file, $path) = @_;
    $path = '' if not defined $path;
    $file = "$path/$file" if length($path);
    if (-f $file) {
        return ($file);
    }
    elsif (-d $file) {
        my @files = ();
        local *DIR;
        opendir(DIR, $file) or die "Can't opendir $file";
        while (my $new_file = readdir(DIR)) {
            next if $new_file =~ /^(\.|\.\.)$/;
            push @files, $self->find_files($new_file, $file);
        }
        return @files;
    }
    return ();
}

sub fix_up_makefile {
    my $self = shift;

    local *MAKEFILE;
    open MAKEFILE, '>> Makefile'
	or die "WriteMakefile can't append to Makefile:\n$!";

    print MAKEFILE "# Added by " . __PACKAGE__ . " $VERSION\n", <<"MAKEFILE";

realclean purge ::
	\$(RM_F) \$(DISTVNAME).tar\$(SUFFIX)

reset :: purge
	\$(PERL) -Iinc -MModule::Install -eModule::Install::purge_extensions

upload :: test dist
	cpan-upload -verbose \$(DISTVNAME).tar\$(SUFFIX)

grok ::
	perldoc Module::Install

distsign::
	cpansign -s

# The End is here ==>
MAKEFILE

    close MAKEFILE;
}

1;
