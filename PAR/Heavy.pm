package PAR::Heavy;

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

	my $modpname = join((($^O eq 'MacOS') ? ':' : '/'), @modparts);
	my $file = "auto/$modpname/$modfname.$dl_dlext";

	if (!$DLCache{$file}++ and defined &PAR::find_par and my $member = PAR::find_par(undef, $file, 1)) {
	    require File::Temp;

	    my ($fh, $filename) = File::Temp::tempfile(
		SUFFIX	=> ".$dl_dlext",
		UNLINK	=> 1
	    );

	    print $fh $member->contents;
	    close $fh;

	    $DLCache{$modfname} = $filename;
	}
    }

    $bootstrap->(@args);
}

########################################################################
# Stub __DATA__ filehandle

package PAR::_data;

sub TIEHANDLE {
    return bless({}, shift);
}

sub DESTROY {
}

sub AUTOLOAD {
    die "Cannot use __DATA__ sections in .par files; ".
        "please install IO::Scalar first!\n";
}

1;
