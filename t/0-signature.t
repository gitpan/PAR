#!/usr/bin/perl
# $File: //member/autrijus/PAR/t/0-signature.t $ $Author: autrijus $
# $Revision: #1 $ $Change: 1512 $ $DateTime: 2002/10/18 20:23:57 $

use strict;
print "1..1\n";

if (eval { require Module::Signature; 1 }) {
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
