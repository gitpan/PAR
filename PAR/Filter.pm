# $File: //member/autrijus/PAR/PAR/Filter.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 1512 $ $DateTime: 2002/10/18 20:23:57 $

package PAR::Filter;
$PAR::Filter::VERSION = '0.01';

use 5.006;
use strict;
use Filter::Simple;

=head1 NAME

PAR::Filter - Run scripts inside a Perl Archive

=head1 VERSION

This document describes version 0.01 of PAR::Filter.

=head1 SYNOPSIS

This runs F<test.pl> or F<script/test.pl> from F<foo.par>:

    % perl -MPAR foo.par test.pl

Same thing, but without loading C<@INC> hooks from C<PAR.pm>,
so F<lib/*> modules inside F<foo.par> cannot be used:

    % perl -MPAR::Filter foo.par test.pl

=head1 DESCRIPTION

This module is used by B<PAR> to run scripts stored inside a
Perl Archive.  See L<PAR> for usage details.

=cut

our @RunCache;

Filter::Simple::FILTER {
    return $_ unless length and (/^PK\003\004/);

    require Archive::Zip;
    require IO::Scalar;

    my $data = $_;
    my $SH = IO::Scalar->new(\$data);
    my $zip = Archive::Zip->new;
    $zip->readFromFileHandle($SH);
    push @RunCache, $zip;

    $_ = << '.';
die "No program file specified" unless @ARGV;

my $file = shift;
foreach my $zip (@PAR::Filter::RunCache) {
    my $member = $zip->memberNamed($file)
	      || $zip->memberNamed("script/$file")
	or die qq(Can't open perl script "$file": No such file or directory);

    eval $member->contents;
    die $@ if $@;
    last;
};
.
};

1;

=head1 SEE ALSO

L<PAR>, L<Filter::Simple>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2001 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or 
modify it under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
