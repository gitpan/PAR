# $File: //depot/cpan/Module-Install/lib/Module/Install/Run.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 1185 $ $DateTime: 2003/03/01 03:47:14 $

package Module::Install::Run;
$VERSION = '0.01';

# check if we can run some command
sub can_run {
    my $command = shift;

    # absolute pathname?
    require ExtUtils::MakeMaker;
    return $command if (-x $command or $command = MM->maybe_command($command));

    require Config;
    return unless defined $Config::Config{path_sep};

    for my $dir (split /$Config::Config{path_sep}/, $ENV{PATH}) {
        my $abs = File::Spec->catfile($dir, $command);
        return $abs if (-x $abs or $abs = MM->maybe_command($abs));
    }

    return;
}

1;
