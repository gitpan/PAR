# $File: //depot/cpan/Module-Install/lib/Module/Install/Makefile.pm $ $Author: autrijus $
# $Revision: #33 $ $Change: 1333 $ $DateTime: 2003/03/09 04:34:29 $ vim: expandtab shiftwidth=4

package Module::Install::Makefile;
use base 'Module::Install::Base';

$VERSION = '0.01';

use strict 'vars';
use vars '$VERSION';

use ExtUtils::MakeMaker ();

sub Makefile { $_[0] }

sub prompt { 
    shift;
    goto &ExtUtils::MakeMaker::prompt;
}

sub makemaker_args {
    my $self = shift;
    my $args = ($self->{makemaker_args} ||= {});
    %$args = ( %$args, @_ ) if @_;
    $args;
}

sub clean_files {
    my $self = shift;
    $self->makemaker_args( clean => { FILES => "@_ " } );
}

sub write {
    my $self = shift;
    die "makefile()->write() takes no arguments\n" if @_;

    my $args = $self->makemaker_args;

    $args->{NAME} = $self->name || $self->determine_NAME($args);
    $args->{VERSION} = $self->version;

    if ($] >= 5.005) {
	$args->{ABSTRACT} = $self->abstract;
	$args->{AUTHOR} = $self->author;
    }

    my $requires = $self->requires;
    if (defined($requires)) {
        $args->{PREREQ_PM} = { map @$_, @$requires };
    }

    $self->admin->update_manifest;

    my %args = map {($_ => $args->{$_})} grep {defined($args->{$_})} keys %$args;
    ExtUtils::MakeMaker::WriteMakefile(%args);

    $self->fix_up_makefile();
}

sub fix_up_makefile {
    my $self = shift;

    local *MAKEFILE;

    if ($self->preamble) {
        open MAKEFILE, '< Makefile' or die $!;
        my $makefile = do { local $/; <MAKEFILE> };
        close MAKEFILE;
        open MAKEFILE, '> Makefile' or die $!;
        print MAKEFILE $self->preamble . $makefile;
        close MAKEFILE;
    }

    open MAKEFILE, '>> Makefile'
        or die "WriteMakefile can't append to Makefile:\n$!";
    print MAKEFILE "# Added by " . __PACKAGE__ . " $VERSION\n", $self->postamble;
    close MAKEFILE;
}

sub preamble {
    my ($self, $text) = @_;
    $self->{preamble} = $text . $self->{preamble} if defined $text;
    $self->{preamble};
}

sub postamble {
    my ($self, $text) = @_;
    my $class = join('::', @{$self->_top}{qw(name dispatch)});

    $self->{postamble} ||= << "END";
realclean purge ::
\t\$(RM_F) \$(DISTVNAME).tar\$(SUFFIX)

reset :: purge
\t\$(RM_RF) inc
\t\$(PERL) -M$class -e \"reset_manifest()\"
\t\$(PERL) -M$class -e \"remove_meta()\"

upload :: test dist
\tcpan-upload -verbose \$(DISTVNAME).tar\$(SUFFIX)

grok ::
\tperldoc Module::Install

distsign ::
\tcpansign -s

END
    $self->{postamble} .= $text if defined $text;
    $self->{postamble};
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

1;

__END__

