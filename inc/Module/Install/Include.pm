# $File: //depot/cpan/Module-Install/lib/Module/Install/Include.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 1284 $ $DateTime: 2003/03/06 19:51:49 $ vim: expandtab shiftwidth=4

package Module::Install::Include;
use base 'Module::Install::Base';

sub include {
    my ($self, $pkg) = @_;

    my $file = $self->admin->find_in_inc($pkg) or return;
    $self->admin->copy_package($pkg, $file);
    return $file;
}

sub include_deps {
    my ($self, $pkg, $perl_version) = @_;
    my $deps = $self->admin->scan_dependencies($pkg, $perl_version) or return;

    foreach my $key (sort keys %$deps) {
        $self->include($key, $deps->{$key});
    }
}

1;
