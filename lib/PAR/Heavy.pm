# $File: //member/autrijus/PAR/lib/PAR/Heavy.pm $ $Author: autrijus $
# $Revision: #12 $ $Change: 7522 $ $DateTime: 2003/08/14 08:22:48 $

package PAR::Heavy;
$PAR::Heavy::VERSION = '0.06';

=head1 NAME

PAR::Heavy - PAR guts

=head1 SYNOPSIS

(internal use only)

=head1 DESCRIPTION

No user-serviceable parts inside.

=cut

########################################################################
# Dynamic inclusion of XS modules

my ($bootstrap, $dl_findfile);	# Caches for code references
my ($dlext);			# Cache for $Config{dlext}

# Adds pre-hooks to Dynaloader's key methods
sub _init_dynaloader {
    return if $bootstrap;
    return unless eval { require DynaLoader; DynaLoader::dl_findfile(); 1 };

    $bootstrap   = \&DynaLoader::bootstrap;
    $dl_findfile = \&DynaLoader::dl_findfile;

    local $^W;
    *{'DynaLoader::dl_expandspec'}  = sub { return };
    *{'DynaLoader::bootstrap'}	    = \&_bootstrap;
    *{'DynaLoader::dl_findfile'}    = \&_dl_findfile;
}

# Return the cached location of .dll inside PAR first, if possible.
sub _dl_findfile {
    return $DLCache{$_[-1]} if exists $DLCache{$_[-1]};
    return $dl_findfile->(@_);
}

# Find and extract .dll from PAR files for a given dynamic module.
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

	# XXX: Multi-platform .dll support in PARs needs better than $Config.
	$dlext ||= do { require Config; $Config::Config{dlext} };

	my $modpname = join((($^O eq 'MacOS') ? ':' : '/'), @modparts);
	my $file = "auto/$modpname/$modfname.$dlext";

	if (!$DLCache{$file}++ and
	    defined &PAR::find_par and
	    my $member = PAR::find_par(undef, $file, 1)
	) {
	    $DLCache{$modfname} = _dl_extract($member, $file);

	    # now extract all associated shared objs in the same auto/ path
	    my $pat = $member->fileName;
	    $pat =~ s{[^/]*$}{};
	    foreach my $member ( $PAR::LastAccessedPAR->members ) {
		next if $member->isDirectory;
		# print "Inspecting ", $member->fileName, " - matching $pat*.$dlext\n";
		my $name = $member->fileName;
		next unless $name =~ /^\/?\Q$pat\E.*\.\Q$dlext\E[^\/]*$/;
		$name =~ s{.*/auto}{auto};
		next if $DLCache{$name}++;
		$name =~ s{.*/}{};
		# print "Extracting $name\n";
		_dl_extract($member, $file, $name);
	    }

	    local $DynaLoader::do_expand = 1;
	    return $bootstrap->(@args);
	}
	elsif ($FullCache{$file}) {
	    $DLCache{$modfname} = $FullCache{$file};
	    local $DynaLoader::do_expand = 1;
	    return $bootstrap->(@args);
	}
    }

    $bootstrap->(@args);
}

sub _dl_extract {
    my ($member, $file, $name) = @_;

    require File::Spec;
    require File::Temp;

    my ($fh, $filename);

    # fix borked tempdir from earlier versions
    if (-e $ENV{PAR_TEMP} and !-d $ENV{PAR_TEMP}) {
	unlink($ENV{PAR_TEMP});
	mkdir($ENV{PAR_TEMP}, 0755);
    }

    if ($ENV{PAR_CLEARTEMP} and !$name) {
	($fh, $filename) = File::Temp::tempfile(
	    DIR		=> ($ENV{PAR_TEMP} || File::Spec->tmpdir),
	    SUFFIX	=> ".$dlext",
	    UNLINK	=> ($^O ne 'MSWin32'),
	);
    }
    else {
	$filename = File::Spec->catfile(
	    ($ENV{PAR_TEMP} || File::Spec->tmpdir),
	    ($name || ($member->crc32String . ".$dlext"))
	);

	open $fh, '>', $filename or die $!
	    unless -r $filename and -e $file
		and -s $file == $member->uncompressedSize;
    }

    if ($fh) {
	binmode($fh);
	print $fh $member->contents;
	close $fh;
	chmod 0755, $filename;
    }

    return $filename;
}

1;

=head1 SEE ALSO

L<PAR>

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

L<http://par.perl.org/> is the official PAR website.  You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2002, 2003 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
