#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/2-pp.t $ $Author: autrijus $
# $Revision: #5 $ $Change: 10644 $ $DateTime: 2004/05/22 16:33:24 $

use strict;
use Cwd;
use Config;
use FindBin;
use File::Spec;

chdir File::Spec->catdir($FindBin::Bin, File::Spec->updir);

my $cwd = getcwd();
my $test_dir = File::Spec->catdir($cwd, 'contrib', 'automated_pp_test');

my $parl = File::Spec->catfile($cwd, 'blib', 'script', "parl$Config{_exe}");

if (!-e $parl) {
    print "1..1\n";
    print "ok 1 # skip 'parl' not found\n";
    exit;
}

warn "*** NOTE: Error messages are harmless as long as tests pass. ***\n";

unshift @INC, File::Spec->catdir($cwd, 'inc');
unshift @INC, File::Spec->catdir($cwd, 'blib', 'lib');
unshift @INC, File::Spec->catdir($cwd, 'blib', 'script');

$ENV{PAR_GLOBAL_CLEAN} = 1;

$ENV{PATH} = join(
    $Config{path_sep},
    grep length,
        File::Spec->catdir($cwd, 'blib', 'script'),
        $ENV{PATH},
);
$ENV{PERL5LIB} = join(
    $Config{path_sep},
    grep length,
        File::Spec->catdir($cwd, 'blib', 'lib'),
        $test_dir,
        $ENV{PERL5LIB},
);

chdir $test_dir;
do "automated_pp_test.pl";

warn "*** NOTE: Error messages are harmless as long as tests pass. ***\n";

__END__
