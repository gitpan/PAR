#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/1-basic.t $ $Author: autrijus $
# $Revision: #10 $ $Change: 9533 $ $DateTime: 2004/01/01 06:52:55 $

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

ok(
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
