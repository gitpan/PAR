#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/1-basic.t $ $Author: autrijus $
# $Revision: #3 $ $Change: 1522 $ $DateTime: 2002/10/19 02:31:09 $

use Test;
BEGIN { plan tests => 8 }

ok(
    `$^X -Mblib -MPAR -It/hello -MHello -e 'Hello::hello'`,
    "Hello, world!\n",
);

ok(
    `$^X -Mblib -MPAR t/hello.par hello.pl`,
    "Hello, world!\nGoodbye, world!\n",
);

ok(
    `$^X -Mblib -MPAR t/hello.par`,
    "Good day!\n",
);

ok(
    `$^X -Mblib script/par.pl t/hello.par`,
    "Good day!\n",
);

require PAR;
PAR->import('t/hello.par');

ok(
    PAR::read_file('script/hello.pl'),
    qr/Hello::hello/,
);

ok( my $zip = PAR::par_handle('t/hello.par') );
ok( my $member = $zip->memberNamed('lib/Hello.pm') );
ok(
    $member->contents,
    qr/package Hello/,
);

__END__
