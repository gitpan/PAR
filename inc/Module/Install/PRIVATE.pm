#line 1 "inc/Module/Install/PRIVATE.pm - /usr/local/lib/perl5/site_perl/5.8.4/Module/Install/PRIVATE.pm"
# $File: //member/autrijus/Module-Install-PRIVATE/lib/Module/Install/PRIVATE.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 5848 $ $DateTime: 2003/05/14 20:24:03 $ vim: expandtab shiftwidth=4

package Module::Install::PRIVATE;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

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
