# $File: //member/autrijus/PAR/lib/PAR/Filter/Bleach.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 8583 $ $DateTime: 2003/10/27 11:27:17 $

package PAR::Filter::Bleach;
use strict;
use base 'PAR::Filter';

=head1 NAME

PAR::Filter::Bleach - Bleach filter

=head1 SYNOPSIS

    PAR::Filter::Bleach->apply(\$code);	# transforms $code

=head1 DESCRIPTION

This filter removes all the unsightly printable characters from
your source file, using an algorithm similar to Damian Conway's
L<Acme::Bleach>.

=cut

sub apply {
    my $ref = $_[1];

    $$ref = unpack("b*", $$ref);
    $$ref =~ tr/01/ \t/;
    $$ref =~ s/(.{9})/$1\n/g;
    $$ref = q($_=<<'';y;\r\n;;d;s;;pack'b*',$_;ee;!$@||die$@).
	    "\n$$ref\n\n";
}

1;

=head1 SEE ALSO

L<PAR::Filter>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

L<http://par.perl.org/> is the official PAR website.  You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
