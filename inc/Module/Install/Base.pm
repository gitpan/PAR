# $File: //depot/cpan/Module-Install/lib/Module/Install/Base.pm $ $Author: autrijus $
# $Revision: #6 $ $Change: 1310 $ $DateTime: 2003/03/08 01:29:15 $ vim: expandtab shiftwidth=4

package Module::Install::Base;

sub new {
    my ($class, %args) = @_;

    foreach my $method (qw(call load)) {
        *{"$class\::$method"} = sub {
            +shift->_top->$method(@_);
        } unless defined &{"$class\::$method"};
    }

    bless(\%args, $class);
}

sub AUTOLOAD {
    my $self = shift;
    goto &{$self->_top->autoload};
}

sub _top { $_[0]->{_top} }

sub admin {
    my $self = shift;
    $self->_top->{admin} or Module::Install::Base::FakeAdmin->new;
}

sub DESTROY {}

package Module::Install::Base::FakeAdmin;

my $Fake;
sub new { $Fake ||= bless(\@_, $_[0]) }
sub AUTOLOAD {}
sub DESTROY {}

1;
