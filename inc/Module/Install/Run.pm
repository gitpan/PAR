# $File: //depot/cpan/Module-Install/lib/Module/Install/Run.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1317 $ $DateTime: 2003/03/08 06:25:04 $ vim: expandtab shiftwidth=4

package Module::Install::Run;
use base 'Module::Install::Base';

$VERSION = '0.01';

# check if we can run some command
sub can_run {
    my ($self, $cmd) = @_;

    require Config;
    require File::Spec;
    require ExtUtils::MakeMaker;

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = File::Spec->catfile($dir, $cmd);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

sub can_cc {
    my $self = shift;
    require Config;
    my $cc = $Config::Config{cc} or return;
    $self->can_run($cc);
}

1;
