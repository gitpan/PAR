# $File: //member/autrijus/PAR/lib/App/Packer/PAR.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 6169 $ $DateTime: 2003/05/29 18:53:54 $ vim: expandtab shiftwidth=4

package App::Packer::Backend::PAR;

use strict;
use vars qw($VERSION %files);

$VERSION = '0.02';

=head1 NAME

App::Packer::Backend::PAR - App::Packer backend for PAR

=head1 DESCRIPTION

This module implements an B<App::Packer> backend based on B<PAR>.

While it currently only have a minimal subset of features in C<pp>, the
authors anticipate this module to carry over C<pp>'s tasks eventually,
in a programmable, modular fashion.

=cut

use Config;
use File::Temp ();
use File::Spec;
use ExtUtils::MakeMaker; # just for maybe_command()
use Archive::Zip;

sub new {
    my $ref = shift;
    my $class = ref( $ref ) || $ref;
    my $parl = _can_run( 'parl' ) or die "Can't find 'parl' executable in PATH";
    bless({ loader => $parl }, $class);
}

sub set_files {
    # todo: -B
    my $self = shift;
    my %data = @_;

    $self->{FILES}{MAIN} =
        $data{main} !~ m/\.pm$/i ? $data{main}{file} : undef;

    # flatten data structure
    my %all_files = 
        map { ( $_->{store_as}, $_->{file} ) }  # and get ->{file} for all elems.
        map { @{$data{$_}} }                    # flatten the array
        grep { $_ ne 'main' } keys %data;       # for all keys != main

    $self->{FILES}{FILES} = \%all_files;
}

sub set_options {
    # -B, pass somehow!
}

sub write {
    my ($self, $exe) = @_;
    my ($fh, $file) = File::Temp::tempfile( UNLINK => 0 );
    my $zip = Archive::Zip->new;
    local *files = $self->{FILES}{FILES};

    $zip->addFile( $self->{FILES}{MAIN}, 'script/main.pl' )
        if defined $self->{FILES}{MAIN};

    foreach my $f ( keys %files ) {
        print "Add: lib/$f\n";
        $zip->addFile( $files{$f}, "lib/$f" );
    }

    $zip->writeToFileHandle( $fh, 1 );
    close $fh;

    system( $self->{loader}, "-q", "-B", "-O$exe", $file );

    unlink $file;
}

sub _can_run {
    my $command = shift;

    for my $dir (
        File::Basename::dirname($0),
        split(/\Q$Config{path_sep}\E/, $ENV{PATH})
    ) {
        my $abs = File::Spec->catfile($dir, $command);
        return $abs if $abs = MM->maybe_command($abs);
    }

    return;
}

1;

__END__

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>,
Mattia Barbon E<lt>MBARBON@cpan.orgE<gt>

PAR has a mailing list, E<lt>par@perl.orgE<gt>, that you can write to;
send an empty mail to E<lt>par-subscribe@perl.orgE<gt> to join the list
and participate in the discussion.

Please send bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

Copyright 2002 by Mattia Barbon E<lt>MBARBON@cpan.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
