# $File: //depot/cpan/Module-Install/lib/Module/Install/Win32.pm $ $Author: autrijus $
# $Revision: #7 $ $Change: 1237 $ $DateTime: 2003/03/04 22:44:36 $ vim: expandtab shiftwidth=4

package Module::Install::Win32;
use base 'Module::Install::Base';

$VERSION = '0.01';

use strict;

# determine if the user needs nmake, and download it if needed
sub check_nmake {
    my $self = shift;
    $self->load('can_run');
    $self->load('get_file');

    require Config;
    return unless (
        $Config::Config{make}                   and
        $Config::Config{make} =~ /^nmake\b/i    and
        $^O eq 'MSWin32'                        and
        !$self->can_run('nmake')
    );

    print "The required 'nmake' executable not found, fetching it...\n";

    require File::Basename;
    my $rv = $self->get_file(
        url         => 'ftp://ftp.microsoft.com/Softlib/MSLFILES/nmake15.exe',
        local_dir   => File::Basename::dirname($^X),
        size        => 51928,
        run         => 'nmake15.exe /o > nul',
        check_for   => 'nmake.exe',
        remove      => 1,
    );

    if (!$rv) {
        die << '.';

------------------------------------------------------------------------

Since you are using Microsoft Windows, you will need the 'nmake' utility
before installation. It's available at:

    ftp://ftp.microsoft.com/Softlib/MSLFILES/nmake15.exe

Please download the file manually, save it to a directory in %PATH (e.g.
C:\WINDOWS\COMMAND), then launch the MS-DOS command line shell, "cd" to
that directory, and run "nmake15.exe" from there; that will create the
'nmake.exe' file needed by this module.

You may then resume the installation process described in README.

------------------------------------------------------------------------
.
    }
}

1;

__END__

