# $File: //depot/cpan/Module-Install/lib/Module/Install/Can.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 1372 $ $DateTime: 2003/03/18 11:18:27 $ vim: expandtab shiftwidth=4

package Module::Install::Can;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

$VERSION = '0.01';

# check if we can run some command
sub can_run {
    my ($self, $cmd) = @_;

    require Config;
    require File::Spec;
    require ExtUtils::MakeMaker;

    return $cmd if (-x $cmd or $cmd = MM->maybe_command($cmd));

    for my $dir ((split /$Config::Config{path_sep}/, $ENV{PATH}), '.') {
        my $abs = File::Spec->catfile($dir, $_[1]);
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
