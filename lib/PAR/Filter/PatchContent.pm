# $File: //member/autrijus/PAR/lib/PAR/Filter/PatchContent.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 8554 $ $DateTime: 2003/10/26 02:34:27 $

package PAR::Filter::PatchContent;
use strict;
use base 'PAR::Filter';

=head1 NAME

PAR::Filter::PatchContent - Content patcher

=head1 SYNOPSIS

    # transforms $code
    PAR::Filter::PatchContent->apply(\$code, $filename, $name);

=head1 DESCRIPTION

This filter fixes PAR-incompatible modules; F<pp> applies it to modules
by default.

=cut

sub PATCH_CONTENT () { {
    'Tk.pm'             => [
        'foreach $dir (@INC)'   => 
        'if (my $member = PAR::unpar($0, $file, 1)) {
            $file =~ s![/\\\\]!_!g;
            return PAR::Heavy::_dl_extract($member,$file,$file);
         }
         if (my $member = PAR::unpar($0, my $name = $_[1], 1)) {
            $name =~ s![/\\\\]!_!g;
            return PAR::Heavy::_dl_extract($member,$name,$name);
         }
         foreach $dir (@INC)', 
    ],
    'Tk/Widget.pm'          => [
        'if (defined($name=$INC{"$pkg.pm"}))' =>
        'if (defined($name=$INC{"$pkg.pm"}) and !ref($name) and $name !~ m!^/loader/!)',
    ],
    'Win32/API/Type.pm'     => [
        'INIT ' => '',
    ],
    'Win32/SystemInfo.pm'   => [
        '$dll .= "cpuspd.dll";' =>
        '$dll = "lib/Win32/cpuspd.dll";
         if (my $member = PAR::unpar($0, $dll, 1)) {
             $dll = PAR::Heavy::_dl_extract($member,"cpuspd.dll","cpuspd.dll");
             $dll =~ s!\\\\!/!g;
         } else { die $! }',
    ],
    'SQL/Parser.pm'   => [
        'my @dialects;' =>
        'my @dialects = ();
         foreach my $member ( $PAR::LastAccessedPAR->members ) {
             next unless $member->fileName =~ m!\bSQL/Dialects/([^/]+)\.pm$!;
             push @dialects, $1;
         }
        ',
    ],
    'diagnostics.pm'        => [
        'CONFIG: ' => 'CONFIG: if (0) ',
        'if (eof(POD_DIAG)) ' => 'if (0 and eof(POD_DIAG)) ',
        'close POD_DIAG' => '# close POD_DIAG',
        'while (<POD_DIAG>) ' =>
        'for(map "$_\\n\\n", split/\\r?\\n(?:\\r?\\n)*/, 
            PAR::read_file("lib/Pod/perldiag.pod") ||
            PAR::read_file("lib/pod/perldiag.pod")
        ) ',
    ],
} };

sub apply {
    my ($class, $ref, $filename, $name) = @_;
    { use bytes; $$ref =~ s/^\xEF\xBB\xBF//; } # remove utf8 BOM

    my @rule = @{PATCH_CONTENT->{$name}||[]} or return $$ref;
    while (my ($from, $to) = splice(@rule, 0, 2)) {
        $$ref =~ s/\Q$from\E/$to/g;
    }
    return $$ref;
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
