#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/1-basic.t $ $Author: autrijus $
# $Revision: #9 $ $Change: 4116 $ $DateTime: 2003/02/06 23:43:43 $

use Test;
BEGIN { plan tests => 8 }

$ENV{PAR_CLEARTEMP} = 1;

ok(
    `"$^X" -Mblib -MPAR -It/hello -MHello -e Hello::hello`,
    "Hello, world!\n",
);

ok(
    `"$^X" -Mblib -MPAR t/hello.par hello.pl`,
    "Hello, world!\nGoodbye, world!\n",
);

ok(
    `"$^X" -Mblib -MPAR t/hello.par nostrict.pl`,
    "No Strict!\n",
);

skip(
    !(eval { require PerlIO::scalar; 1 } or eval { require IO::Scalar ; 1}),
    `"$^X" -Mblib -MPAR t/hello.par data.pl`,
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
