#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/0-signature.t $ $Author: autrijus $
# $Revision: #2 $ $Change: 1740 $ $DateTime: 2002/10/28 23:20:01 $

use strict;
print "1..1\n";

if (eval { require Socket; Socket::inet_aton('pgp.mit.edu') } and
    eval { require Module::Signature; 1 }
) {
    (Module::Signature::verify() == Module::Signature::SIGNATURE_OK())
	or print "not ";
    print "ok 1 # Valid signature\n";
}
else {
    warn "# Next time around, consider install Module::Signature,\n".
	 "# so you can verify the integrity of this distribution.\n";
    print "ok 1 # skip - Module::Signature not installed\n";
}

__END__
