#line 1 "inc/Module/Install/PRIVATE/PAR.pm - /usr/local/lib/perl5/site_perl/5.8.1/Module/Install/PRIVATE/PAR.pm"
# $File: //member/autrijus/Module-Install-PRIVATE/lib/Module/Install/PRIVATE/PAR.pm $ $Author: autrijus $
# $Revision: #12 $ $Change: 9361 $ $DateTime: 2003/12/20 01:10:25 $ vim: expandtab shiftwidth=4

package Module::Install::PRIVATE::PAR;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

use 5.006;
use Config ();

my %no_parl  = ();

sub Autrijus_PAR {
    my $self = shift;
    my $bork = $no_parl{$^O};
    my $cc   = $self->can_cc unless $bork;
    my $par  = $self->fetch_par('', '', !$cc) unless $cc or $bork;
    my $exe  = $Config::Config{_exe};
    my $dynperl = $Config::Config{useshrplib} && ($Config::Config{useshrplib} ne 'false');

    if ($bork) {
        warn "Binary loading known to fail on $^O; won't generate 'script/parl$exe'!\n";
    }
    elsif (!$par and !$cc) {
        warn "No compiler found, won't generate 'script/parl$exe'!\n";
    }

    # XXX: this branch is currently not entered
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
    push @bin, ("script/parldyn$exe", "myldr/static$exe") if $dynperl;

    if ($par) {
        open _, "> $bin[1]" or die $!;
        close _;
    }
    elsif (-f $bin[1] and not -s $bin[1]) {
        unlink $bin[1];
    }

    $self->clean_files(@bin) if $par or $cc;

    $self->makemaker_args(
        MAN1PODS		=> {
            'script/par.pl'	=> 'blib/man1/par.pl.1',
            'script/pp'	        => 'blib/man1/pp.1',
            'script/tkpp'       => 'blib/man1/tkpp.1',
          ($par or $cc) ? (
            'script/parl.pod'   => 'blib/man1/parl.1',
          ) : (),
        },
        EXE_FILES		=> [
            'script/par.pl',
            'script/pp',
            'script/tkpp',
          (!$par and $cc) ? (
            "script/parl$exe",
            ($^O eq 'MSWin32' and Win32::IsWinNT()) ? (
                "contrib/replaceicon$exe",
            ) : (),
            $dynperl ? (
                "script/parldyn$exe",
            ) : (),
          ) : (),
        ],
        DIR                     => [
          (!$par and $cc) ? (
            'myldr'
          ) : (),
        ],
        NEEDS_LINKING	        => 1,
    );
}

sub Autrijus_PAR_fix {
    my $self = shift;
    require Config;
    my $exe = $Config::Config{_exe};
    return unless $exe eq '.exe';

    open IN, '< Makefile' or return;
    open OUT, '> Makefile.new' or return;
    while (<IN>) {
        next if /^\t\$\(FIXIN\) .*\Q$exe\E$/;
        next if /^\@\[$/ or /^\]$/;
        print OUT $_;
    }
    close OUT;
    close IN;
    unlink 'Makefile';
    rename 'Makefile.new' => 'Makefile';
}

1;
