#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/1-basic.t $ $Author: autrijus $
# $Revision: #2 $ $Change: 1515 $ $DateTime: 2002/10/18 20:51:53 $

use Test;
BEGIN { plan tests => 6 }

ok(
    `$^X -Mblib -MPAR -It/hello -MHello -e 'Hello::hello'`,
    "Hello, world!\n",
);

ok(
    `$^X -Mblib -MPAR t/hello.par hello.pl`,
    "Hello, world!\nGoodbye, world!\n",
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
