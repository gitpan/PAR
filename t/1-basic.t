#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/1-basic.t $ $Author: autrijus $
# $Revision: #5 $ $Change: 1566 $ $DateTime: 2002/10/20 12:22:25 $

use Test;
BEGIN { plan tests => 7 }

ok(
    `$^X -Mblib -MPAR -It/hello -MHello -e 'Hello::hello'`,
    "Hello, world!\n",
);

ok(
    `$^X -Mblib -MPAR t/hello.par hello.pl`,
    "Hello, world!\nGoodbye, world!\n",
);

skip(
    !(eval { require PerlIO::scalar; 1 } or eval { require IO::Scalar ; 1}),
    `$^X -Mblib -MPAR t/hello.par data.pl`,
    "Data section\nData reflection\n",
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
