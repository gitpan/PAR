# $File: //member/autrijus/Module-Install-_Autrijus/lib/Module/Install/_Autrijus.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 4646 $ $DateTime: 2003/03/08 15:37:12 $ vim: expandtab shiftwidth=4

package Module::Install::_Autrijus;
use base 'Module::Install::Base';

sub Autrijus { $_[0] }

sub write {
    my ($self, $name) = @_;

    $self->author('Autrijus Tang (autrijus@autrijus.org)');
    $self->par_base('AUTRIJUS');
    $self->name($name ||= $self->name);

    my $method = "Autrijus_$name";
    $self->$method;
}

1;
