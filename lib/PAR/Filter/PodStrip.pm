# $File: //member/autrijus/PAR/lib/PAR/Filter/PodStrip.pm $ $Author: autrijus $
# $Revision: #3 $ $Change: 8554 $ $DateTime: 2003/10/26 02:34:27 $

package PAR::Filter::PodStrip;
use strict;
use base 'PAR::Filter';

=head1 NAME

PAR::Filter::PodStrip - POD-stripping filter

=head1 SYNOPSIS

    # transforms $code
    PAR::Filter::PodStrip->apply(\$code, $filename, $name);

=head1 DESCRIPTION

This filter strips away all POD sections, but preserves the original
file name and line numbers via the C<#line> directive.

=cut

sub apply {
    my ($class, $ref, $filename, $name) = @_;

    no warnings 'uninitialized';

    my $data = '';
    $data = $1 if $$ref =~ s/((?:^__DATA__$).*)//ms;

    my $line = 1;
    if ($$ref =~ /^=(?:head\d|pod|begin|item|over|for|back|end)\b/) {
        $$ref = "\n$$ref";
        $line--;
    }
    $$ref =~ s{(
	(.*?\n)
	=(?:head\d|pod|begin|item|over|for|back|end)\b
	.*?\n
	(?:=cut[\t ]*[\r\n]*?|\Z)
	(\r?\n)?
    )}{
	my ($pre, $post) = ($2, $3);
        "$pre#line " . (
	    $line += ( () = ( $1 =~ /\n/g ) )
	) . $post;
    }gsex;

    $$ref = '#line 1 "' . ($filename) . "\"\n" . $$ref
        if length $filename;
    $$ref =~ s/^#line 1 (.*\n)(#!.*\n)/$2#line 2 $1/g;
    $$ref .= $data;
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
