# $File: //member/autrijus/Module-Install-_Autrijus/lib/Module/Install/_Autrijus/PAR.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 4660 $ $DateTime: 2003/03/08 19:50:57 $ vim: expandtab shiftwidth=4

package Module::Install::_Autrijus::PAR;
use base 'Module::Install::Base';

use 5.006;
use Config ();

sub Autrijus_PAR {
    my $self = shift;
    my $cc   = $self->can_cc;
    my $par  = $self->fetch_par('', '', !$cc);
    my $exe  = $Config::Config{_exe};

    warn "No compiler found, won't generate 'script/parl$exe'!\n"
        unless $par or $cc;

    if ($cc and $par) {
        my $answer = $self->prompt(
            "*** Pre-built PAR package found.  Use it instead of recompiling [y/N]?"
        );
        if ($answer !~ /^[Yy]/) {
            $self->load('preamble')->{preamble} = '';
            $par = '';
        }
    } 

    my @bin = ("script/parl$exe", "myldr/par$exe");

    if ($par) {
        open _, "> myldr/par$exe" or die $!;
        close _;
    }

    $self->clean_files(@bin) if $par or $cc;

    $self->makemaker_args(
        MAN1PODS		=> {
            'script/par.pl'	=> 'blib/man1/par.pl.1',
            'script/pp'	        => 'blib/man1/pp.1',
          ($par or $cc) ? (
            'script/parl.pod'   => 'blib/man1/parl.1',
          ) : (),
        },
        EXE_FILES		=> [
            'script/par.pl',
            'script/pp',
          (!$par and $cc) ? (
            "script/parl$exe",
          ) : (),
        ],
        NEEDS_LINKING	        => 1,
    );
}

1;
