# $File: //member/autrijus/Module-Install-private/lib/Module/Install/private.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 4807 $ $DateTime: 2003/03/19 14:10:44 $ vim: expandtab shiftwidth=4

package Module::Install::private;
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

sub fix {
    my $self = shift;
    $name = $self->name;
    my $method = "Autrijus_${name}_fix";
    $self->$method;
}

1;
