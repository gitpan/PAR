# $File: //member/autrijus/PAR/PAR/Heavy.pm $ $Author: autrijus $
# $Revision: #4 $ $Change: 2054 $ $DateTime: 2002/11/08 14:37:27 $

package PAR::Heavy;
$PAR::Heavy::VERSION = '0.02';

=head1 NAME

PAR::Heavy - PAR guts

=head1 SYNOPSIS

(internal use only)

=head1 DESCRIPTION

No user-serviceable parts inside.

=cut

########################################################################
# Dynamic inclusion of XS modules

my ($bootstrap, $dl_findfile);	# caches for code references

sub _init_dynaloader {
    return if $bootstrap;
    return unless eval { require DynaLoader; DynaLoader::dl_findfile(); 1 };

    $bootstrap   = \&DynaLoader::bootstrap;
    $dl_findfile = \&DynaLoader::dl_findfile;

    no strict 'refs';
    no warnings 'redefine';
    *{'DynaLoader::bootstrap'}   = \&_bootstrap;
    *{'DynaLoader::dl_findfile'} = \&_dl_findfile;
}

sub _dl_findfile {
    # print "Finding $_[-1]. DLCache reads ", %DLCache, "\n";

    return $DLCache{$_[-1]} if exists $DLCache{$_[-1]};
    return $dl_findfile->(@_);
}

my $dl_dlext;
sub _bootstrap {
    my (@args) = @_;
    my ($module) = $args[0];
    my (@dirs, $file);

    if ($module) {
	my @modparts = split(/::/, $module);
	my $modfname = $modparts[-1];

	$modfname = &DynaLoader::mod2fname(\@modparts)
	    if defined &DynaLoader::mod2fname;

	if (($^O eq 'NetWare') && (length($modfname) > 8)) {
	    $modfname = substr($modfname, 0, 8);
	}

	$dl_dlext ||= do { require Config; $Config::Config{dlext} };

	my $modpname = join((($^O eq 'MacOS') ? ':' : '/'), @modparts);
	my $file = "auto/$modpname/$modfname.$dl_dlext";

	if (!$DLCache{$file}++ and
	    defined &PAR::find_par and
	    my $member = PAR::find_par(undef, $file, 1)
	) {
	    require File::Temp;

	    my ($fh, $filename) = File::Temp::tempfile(
		SUFFIX	=> ".$dl_dlext",
		UNLINK	=> 1
	    );

	    local $PAR::__reading = 1;
	    print $fh $member->contents;
	    close $fh;

	    $DLCache{$modfname} = $filename;
	}
    }

    $bootstrap->(@args);
}

1;

=head1 SEE ALSO

L<PAR>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

=head1 COPYRIGHT

Copyright 2002 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
