# $File: /depot/local/PAR/trunk/lib/PAR/Filter/Obfuscate.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 11731 $ $DateTime: 2004-08-30T22:40:26.326020Z $

package PAR::Filter::Obfuscate;

use strict;
use base 'PAR::Filter';
use File::Temp ();

=head1 NAME

PAR::Filter::Obfuscate - Obfuscating filter

=head1 SYNOPSIS

    PAR::Filter::Obfuscate->apply(\$code); # transforms $code

=head1 DESCRIPTION

This filter uses L<B::Deobfuscate> (available separately from CPAN) to
turn the script into comment-free, architecture-independent Perl code
with mangled variable names.

=head1 CAVEATS

A harmless message will be displayed during C<pp>:

    /tmp/8ycSoLaSI1 syntax OK

Please just ignore it. :-)

=cut

sub apply {
    my $ref = $_[1];

    my ($fh, $in_file) = File::Temp::tempfile();
    print $fh $$ref;
    close $fh;

    require B::Deobfuscate;
    $$ref = `$^X -MO=Deobfuscate $in_file`;
    warn "Cannot transform $in_file$! ($?)\n" if $?;
}

1;

=head1 SEE ALSO

L<PAR::Filter>, L<B::Deobfuscate>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

L<http://par.perl.org/> is the official PAR website.  You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
