package App::Packer::Backend::PAR;

use 5.006;
use strict;
use warnings;

use Config;

use Archive::Zip;

use Cwd;
use ExtUtils::MakeMaker; # just for maybe_command()
use File::Basename;
use File::Spec;
use File::Find;
use File::Temp qw(tempfile);
use Getopt::Long; 
use Module::ScanDeps 0.10;
use PAR::Filter;
local($|) = 1;

our $VERSION = 0.06;

use constant LEGAL_OPTIONS => {
	'M|add:s@'			=> 'Include modules',
	'a|extra:s@'		=> 'additional files to pack',
	'A|listextra:s'		=> 'file containing list of additional files to pack',
	'B|bundle'			=> 'Bundle core modules',
	'C|clean',			=> 'Clean up temporary files',
	'c|compile'			=> 'Compile code to get dependencies',
	'd|dependent'		=> 'Do not package libperl',
	'e|eval:s'			=> 'Packing one-liner',
	'x|execute'			=> 'Execute code to get dependencies',
	'X|exclude:s@'		=> 'Exclude modules',
	'f|filter:s@'		=> 'Input filters for scripts',
	'g|gui'				=> 'No console window',
	'h|help'			=> 'Help me',
	'i|icon:s'			=> 'Icon file',
	'N|info'			=> 'Executable header info',
	'I|lib:s@'			=> 'Include directories (for perl)',
	'l|link:s@'			=> 'Include additional shared libraries',
	'L|log:s'			=> 'Where to log packaging process information',
	'F|modfilter:s@'	=> 'Input filter for perl modules',
	'm|multiarch'		=> 'Build multiarch PAR file',
	'n|noscan'			=> 'Skips static scanning',
	'o|output:s'		=> 'Output file',
	'p|par'				=> 'Generate PAR only',
	'P|perlscript'		=> 'Generate perl script',
	'r|run'				=> 'Run the resulting executable',
	'S|save'			=> 'Preserve intermediate PAR files',
	's|sign'			=> 'Sign PAR files',
	'v|verbose:s'		=> 'Verbosity level',
	'V|version'			=> 'Show version'
};

my $_longopt = 
{
	qw(
		M add a extra A listextra B bundle
		C clean c compile d dependent e eval x execute
		X exclude f filter g gui h help i icon N info
		I lib l link L log F modfilter m multiarch n noscan
		o output p par P perlscript r run S save
		s sign v verbose V version
	)
};

my $_shortopt =
{
	qw(
		add M extra a listextra A bundle B 
		clean C compile c dependent d eval e 
		execute x exclude X filter f gui g help h icon i info N 
		lib I link l log L modfilter F multiarch m noscan n 
		output o par p perlscript P run r save S 
		sign s verbose v version V 
	)
};

my %_zip_args = 
(
	'desiredCompressionMethod'
		=> Archive::Zip::COMPRESSION_DEFLATED(),
	'desiredCompressionLevel'
		=> Archive::Zip::COMPRESSION_LEVEL_BEST_COMPRESSION(),
);


my $_legal_opts = {};

sub options { LEGAL_OPTIONS };

sub new
{
	my ($type, $args, $opt, $frontend) = @_;

	$SIG{INT} = sub { exit() } if (!$SIG{INT}); 
							# exit gracefully and clean up after ourselves.
							# note.. in constructor because of conflict.

	$ENV{PAR_RUN} = 1;
	my $self = bless {}, $type;

	$self->set_args($args) 	if ($args);
	$self->set_options($opt) 	if ($opt);
	$self->set_front($frontend)	if ($frontend);

	return($self);
}

sub set_options
{
	my ($self, %opt) = @_;	
	
	$self->{options} = \%opt;
	_translate_options($self->{options});

	$self->{parl} ||= _can_run("parl$Config{_exe}") or die("Can't find par loader");
	$self->{dynperl} ||= $Config{useshrplib} && ($Config{useshrplib} ne 'false');
	$self->{script_name} = $opt{script_name} || $0;
}


sub add_options
{
	my ($self, %opts) = @_;

	my $opt = $self->{options};
	%$opt = (%$opt, %opts);

	_translate_options($opt);
}

sub _translate_options
{
	my ($opt) = @_;

	_create_legal_hash(LEGAL_OPTIONS, $_legal_opts);

	my $key;
	foreach $key (keys(%$opt))
	{
		my $value = $opt->{$key};

		if (!$_legal_opts->{$key})
		{
			warn "'$key' is not a legal option!\n";
			usage();
		}
		else
		{
			$opt->{$key} = $value;
			my $other = ($_longopt->{$key})? $_longopt->{$key} : $_shortopt->{$key};
			$opt->{$other} = $value;
		}
	}
}

sub add_args
{
	my ($self, @arg) = @_;
	push(@{$self->{args}}, @arg);
}

sub set_args
{
	my ($self, @args) = @_;

	unshift(@args, split ' ', $ENV{PP_OPTS}) if ($ENV{PP_OPTS});
	$self->{args} = \@args;
}

sub set_front
{
	my ($self, $frontend) = @_;

	my $opt = $self->{options};
	$self->{frontend} = $frontend || $opt->{frontend};
}

sub _check_read 
{
	my ($self, @files) = @_;

	my $sn = $self->{script_name};
	foreach my $file (@files) 
	{
		unless (-r $file) 
		{
		    _die($self, "$sn: Input file $file is a directory, not a file\n") if (-d _);
		    unless (-e _) 
			{
		        _die($self, "$sn: Input file $file was not found\n");
		    } 
			else 
			{
		        _die($self, "$sn: Cannot read input file $file: $!\n");
		    }
		}
		unless (-f _) 
		{
		    # XXX: die?  don't try this on /dev/tty
		    warn "$sn: WARNING: input $file is not a plain file\n";
		} 
	}
}

sub _check_write 
{
	my ($self, @files) = @_;

	foreach my $file (@files) 
	{
		if (-d $file) 
		{
		    _die($self, "$0: Cannot write on $file, is a directory\n");
		}
		if (-e _) 
		{
		    _die($self, "$0: Cannot write on $file: $!\n") unless -w _;
		} 
		unless (-w cwd()) 
		{
		    _die($self, "$0: Cannot write in this directory: $!\n");
		}
	}
}

sub _check_perl 
{
	my ($self, $file) = @_;
	return if ($self->_check_par($file));

	unless (-T $file) 
	{
		warn "$0: Binary `$file' sure doesn't smell like perl source!\n";

		if (my $file_checker = _can_run("file")) 
		{
		    print "Checking file type... ";
		    system($file_checker, $file);
		}
		_die($self, "Please try a perlier file!\n");
	}

	open(my $handle, "<", $file) or _die("XXX: Can't open $file: $!");

	local $_ = <$handle>;
	if (/^#!/ && !/perl/) 
	{
		_die($self, "$0: $file is a ", /^#!\s*(\S+)/, " script, not perl\n");
	} 
}

sub _sanity_check 
{
	my ($self) = @_;

	my $input = $self->{input};
	my $output = $self->{output};

	my $sn = $self->{script_name};

	# Check the input and output files make sense, are read/writable.
	if ("@$input" eq $output) 
	{
		my $a_out = $self->_a_out();

		if ("@$input" eq $a_out) 
		{
		    _die($self, 
				"$0: Packing $a_out to itself is probably not what you want to do.\n");
		    # You fully deserve what you get now. No you *don't*. typos happen.
		} 
		else 
		{
		    warn "$sn: Will not write output on top of input file, ",
		        "packing to $a_out instead\n";
		    $self->{output} = $a_out;
		}
	}
}

sub _a_out 
{
	my ($self) = @_;

	my $opt = $self->{options};

	return 'a' .  
	(
		$opt->{p} ? '.par' :
		$opt->{P} ? '.pl' : ($Config{_exe} || '.out')
	);
}

sub _parse_opts
{
	my ($self) = @_;

	my $args = $self->{args};
	my $opt = $self->{options}; 

	_verify_opts($opt);
	$opt->{v} = (defined($opt->{v}))? $opt->{v} : 
					($ENV{PAR_VERBOSITY})? $ENV{PAR_VERBOSITY} :
					0;

	$opt->{L} = (defined($opt->{L}))? $opt->{L} :
					($ENV{PAR_LOG})? $ENV{PAR_LOG} :
					'';

	$opt->{p} = 1 if ($opt->{m});
	$opt->{v} = 1 if (exists($opt->{v}) && $opt->{v} eq '');
	$opt->{B} = 1 unless ($opt->{p} || $opt->{P});

	helpme() if ($opt->{h});
	show_version() if ($opt->{V});
	$self->{output} = $opt->{o} || $self->_a_out();
	$opt->{o} = $opt->{o} || $self->_a_out();
	$self->{script_name} = $self->{script_name} || $opt->{script_name} || $0;
	my $sn = $self->{script_name};


	my $lf;

	my $logfh;
	open($logfh, '>>', $opt->{L}) || 
			_die ($self, "XXX: Cannot open log: $!") if ($opt->{L});

	$self->{logfh} = $logfh if ($logfh);

	if ($opt->{e}) 
	{
		warn "$sn: using -e 'code' as input file, ignoring @$args\n" 
				if (@$args and !$opt->{r});

		my ($fh, $fake_input) = tempfile("ppXXXXX", SUFFIX => ".pl", UNLINK => 1); 

		print $fh $opt->{e};
		close $fh;
		$self->{input} = [ $fake_input ];
	}
	else 
	{
		$self->{input} ||= [];

		push(@{$self->{input}},  shift @$args) if (@$args);
		my $sn = $self->{script_name};

		push( @{$self->{input}}, @$args ) if (@$args and !$opt->{r});
		my $in = $self->{input};

		$self->_check_read(@$in) if (@$in);
		$self->_check_perl(@$in) if (@$in);
		$self->_sanity_check();
	}
}

sub _verify_opts
{
	my ($opt) = @_;

	_create_legal_hash(LEGAL_OPTIONS, $_legal_opts);

	my $show_usage = 0;
	my $key;
	foreach $key (keys(%$opt))
	{
		if (!$_legal_opts->{$key})
		{
		    warn "'$key' is not a legal option!\n";
			$show_usage = 1;
			
		}
	}
	usage() if ($show_usage);
}

sub _create_legal_hash
{
	my ($hashin, $hashout) = @_;

	return() if (%$hashout);

	my $key;
	foreach $key (keys(%$hashin))
	{
		my (@keys) = ($key =~ m"\|")? ($key =~ m"(.*?)\|(.*?)(?::|\z)") : ($key);
		@{$hashout}{@keys} = ($hashin->{$key})x @keys;
	}
}

sub usage
{
	my $key;
	foreach $key (sort keys(%{+LEGAL_OPTIONS}))
	{
		print STDERR "\n$key" ." " x (20 - length($key)) . LEGAL_OPTIONS->{$key} . "\n";
	}
	print STDERR "\n\n";
}

sub go
{
	my ($self) = @_;

	$self->_parse_opts();

	my $opt = $self->{options};

	$self->_setup_run();
	$self->generate_pack ( { nosetup => 1 });
	$self->run_pack ( { nosetup => 1} ) if ($opt->{r});
}

sub _setup_run
{
	my ($self) = @_;

	my $opt = $self->{options};
	my $sn = $self->{script_name};
	my $args = $self->{args};

	_die($self, 
			"$sn: No input files specified\n") unless @{$self->{input}} or $opt->{M};

	my $PARL;

	unless (eval { require PAR; 1 }) 
	{
		$PARL ||= _can_run("parl$Config{_exe}") or die("Can't find par loader");
		exec($PARL, $sn, @$args);
	}

	my $output = $self->{output};
	$self->_check_write($output);
}

sub generate_pack
{
	my ($self, $config) = @_;

	$config ||= {};
	$self->_parse_opts() if (!$config->{nosetup});
	$self->_setup_run() if (!$config->{nosetup});

	my $input = $self->{input};
	my $opt = $self->{options};

	$self->_vprint(0, "Packing @$input");

	if ($self->_check_par($input->[0])) 
	{
		# invoked as "pp foo.par" - never unlink it
		$self->{par_file} = $input->[0];
		$opt->{S} = 1;
		$self->_par_to_exe();
	}
	else 
	{
		$self->_compile_par();
	}
}

sub run_pack
{
	my ($self, $config) = @_;

	$config ||= {};

	$self->_parse_opts() if (!$config->{nosetup});
	$self->_setup_run() if (!$config->{nosetup});
 
	my $opt = $self->{options};
	my $output = $self->{output};
	my $args   = $self->{args};

	$output = File::Spec->catfile(".", $output);

	my @loader = ();
	push( @loader, $^X) if ($opt->{P});
	push( @loader, $^X, "-MPAR") if ($opt->{p});
	$self->_vprint(0, "Running @loader $output @$args");
	system(@loader, $output, @$args);
	exit(0);
}

sub helpme 
{
	print "Perl Packager, version $VERSION (PAR version $PAR::VERSION)\n\n";
	{
		no warnings;
		exec "pod2usage $0";
		exec "perldoc $0";
		exec "pod2text $0";
	}
}

sub show_version 
{
	print << ".";
Perl Packager, version $VERSION (PAR version $PAR::VERSION)
Copyright 2002, 2003, 2004 by Autrijus Tang <autrijus\@autrijus.org>

Neither this program nor the associated "parl" program impose any
licensing restrictions on files generated by their execution, in
accordance with the 8th article of the Artistic License:

	"Aggregation of this Package with a commercial distribution is
	always permitted provided that the use of this Package is embedded;
	that is, when no overt attempt is made to make this Package's
	interfaces visible to the end user of the commercial distribution.
	Such use shall not be construed as a distribution of this Package."

Therefore, you are absolutely free to place any license on the resulting
executable, as long as the packed 3rd-party libraries are also available
under the Artistic License.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.  There is NO warranty; not even for
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

.
	exit;
}

sub pod_strip 
{
	my ($pl_text, $filename) = @_;

	no warnings 'uninitialized';

	my $data = '';
	$data = $1 if ($pl_text =~ s/((?:^__DATA__$).*)//ms);

	my $line = 1;
	if ($pl_text =~ /^=(?:head\d|pod|begin|item|over|for|back|end)\b/) 
	{
		$pl_text = "\n$pl_text";
		$line--;
	}
	$pl_text =~ s{(
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
	$pl_text = '#line 1 "' . ($filename) . "\"\n" . $pl_text
		if (length $filename);
	$pl_text =~ s/^#line 1 (.*\n)(#!.*\n)/$2#line 2 $1/g;

	return $pl_text . $data;
}

sub _compile_par 
{
	my ($self) = @_;

	my @SharedLibs;
	local(@INC) = @INC;

	my $lose = $self->{pack_attrib}{lose};
	my $opt = $self->{options};

	my $par_file = $self->get_par_file();

	$self->_add_pack_manifest();
	$self->_add_add_manifest();
	$self->_make_manifest();
	$self->_writezip();

	$self->_signpar() if ($opt->{s});
	$self->_par_to_exe() unless($opt->{p});
	
	if ($lose) 
	{
		$self->_vprint( 2, "Unlinking $par_file");
		unlink $par_file or _die($self, "Can't unlink $par_file: $!"); 
	}
}

sub _writezip
{
	my ($self) = @_;

	my $old_member 	 = 	$self->{pack_attrib}{old_member};
	my $oldsize 	 =	$self->{pack_attrib}{old_size}; 
	my $par_file	 = 	$self->{par_file};
	my $add_manifest = 	$self->add_manifest();

	my $zip = $self->{zip};

	if ($old_member) 
	{
		$zip->overwrite();
	}
	else 
	{
		$zip->writeToFileNamed($par_file);
	}

	my $newsize = -s $par_file;
	$self->_vprint
	( 
		2, sprintf(
			"*** %s: %d bytes read, %d compressed, %2.2d%% saved.\n",
			$par_file, $oldsize, $newsize, (100 - ($newsize / $oldsize * 100))
		)
	);
}

sub _signpar
{
	my ($self) = @_;
	
	my $opt = $self->{options};
	my $par_file = $self->{par_file};

	if 
	( 
		eval 
		{ 
			require PAR::Dist; require Module::Signature; 
			Module::Signature->VERSION >= 0.25 
		} 
	) 
	{
		    $self->_vprint(0, "Signing $par_file");
		    PAR::Dist::sign_par($par_file);
	}
	else 
	{
	    $self->_vprint( -1, "*** Signing requires PAR::Dist with Module::Signature 0.25 or later.  Skipping");
	}
}

sub _add_add_manifest
{
	my ($self) = @_;

	my $opt 			= $self->{options};
	my $add_manifest	= $self->add_manifest_hash();
	my $par_file 		= $self->{par_file};

	$self->_vprint(1, "Writing extra files to $par_file") if (%$add_manifest);
	$self->{zip} ||= Archive::Zip->new;
	my $zip = $self->{zip};

	my $in;
	foreach $in (keys(%$add_manifest))
	{
		my $value = $add_manifest->{$in};
		$self->_addfile($zip, $in, $value); 
	}
}

sub _make_manifest_file
{

	my ($self) = @_;

	my $input = $self->{input};

	my $full_manifest = $self->{full_manifest};
	my $dep_manifest  = $self->{dep_manifest};
	my $add_manifest  = $self->{add_manifest};

	my $opt = $self->{options};
	my $par_file = $self->{par_file};
	my $output = $self->{output};

	my $clean = ($opt->{C} ? 1 : 0);
	my $dist_name = ($opt->{p} ? $par_file : $output);
	my $verbatim = ($ENV{PAR_VERBATIM} || 0);



	my $manifest = join("\n", '    <!-- accessible as jar:file:///NAME.par!/MANIFEST in compliant browsers -->', (sort keys %$full_manifest), q(    # <html><body onload="var X=document.body.innerHTML.split(/\n/);var Y='<iframe src=&quot;META.yml&quot; style=&quot;float:right;height:40%;width:40%&quot;></iframe><ul>';for(var x in X){if(!X[x].match(/^\s*#/)&&X[x].length)Y+='<li><a href=&quot;'+X[x]+'&quot;>'+X[x]+'</a>'}document.body.innerHTML=Y">));

	my $meta_yaml = << "YAML";
build_requires: {}
conflicts: {}
dist_name: $dist_name
distribution_type: par
dynamic_config: 0
generated_by: 'Perl Packager version $VERSION'
license: unknown
par:
  clean: $clean
  signature: ''
  verbatim: $verbatim
  version: $PAR::VERSION
YAML

	$self->_vprint( 2, "... making $_") for qw(MANIFEST META.yml);

	my %manifest = map { $_ => 1 } ('MANIFEST', 'META.yml');

	$full_manifest->{'MANIFEST'} = [ 'string', $manifest   ];
	$full_manifest->{'META.yml'} = [ 'string', $meta_yaml  ];

	$dep_manifest->{'MANIFEST'}  = [ 'string', $manifest   ];
	$dep_manifest->{'META.yml'}  = [ 'string', $meta_yaml  ];

}

sub get_par_file
{
	my ($self) = @_;

	return($self->{par_file}) if ($self->{par_file});

	my $input = $self->{input};
	my $output = $self->{output};

	my $par_file;
	my $cfh;

	my $opt = $self->{options};

	if ($opt->{S} || $opt->{p}) 
	{
		# We need to keep it.
		if ($opt->{e} or !@$input) 
		{
		    $par_file = "a.par";
		} 
		else 
		{
		    $par_file = $input->[0];

		    # File off extension if present
		    # hold on: plx is executable; also, careful of ordering!

		    $par_file =~ s/\.(?:p(?:lx|l|h)|m)\z//i;
		    $par_file .= ".par";
		}

		$par_file = $output if ($opt->{p} && $output =~ /\.par\z/i);

		$output = $par_file;

		$self->_check_write($par_file);
	} 
	else 
	{
		# Don't need to keep it, be safe with a tempfile.

		$self->{pack_attrib}{lose} = 1;
		($cfh, $par_file) = tempfile("ppXXXXX", SUFFIX => ".par"); 
		close $cfh; # See comment just below
	}
	$self->{par_file} = $par_file;
	return($par_file);
}

sub set_par_file
{
	my ($self, $file) =  @_;

	$self->{par_file} = $file;
	$self->_check_write($file);
}	

sub pack_manifest_hash
{
	my ($self) = @_;

	my @SharedLibs;
	return($self->{pack_manifest}) if ($self->{pack_manifest});

	$self->{pack_manifest} ||= {};
	$self->{full_manifest} ||= {};
	my $full_manifest = $self->{full_manifest};
	my $dep_manifest  = $self->{pack_manifest};

	my $sn = $self->{script_name};
	my $fe = $self->{frontend};

	my $opt = $self->{options};
	my $input = $self->{input};
	my $output = $self->{output};

	my $root = '';
	$root = "$Config{archname}/" if ($opt->{m});
	$self->{pack_attrib}{root} = '';

	my $par_file = $self->{par_file};
	my (@modules, @data, @exclude);

	foreach my $name (@{$opt->{M} || []}) 
	{ 
		_name2moddata($name, \@modules, \@data); 
	}

	foreach my $name ('PAR', @{$opt->{X} || []}) 
	{
		_name2moddata($name, \@exclude, \@exclude);
	}

	my %map;

	unshift( @INC, @{$opt->{I} || []});
	unshift( @SharedLibs, map _find_shlib($_, $sn), @{$opt->{l} || []});

	my $inc_find = _obj_function($fe, '_find_in_inc');

	my %skip = map { (&$inc_find($_) => 1) } @exclude;
	my @files = (map (&$inc_find($_), @modules), @$input);

	my $scan_dispatch = 
		$opt->{n} ? _obj_function($fe, 'scan_deps_runtime') :
		       		_obj_function($fe, 'scan_deps');

	$scan_dispatch->
	(
		rv      => \%map,
		files   => \@files,
		execute => $opt->{x},
		compile => $opt->{c},
		skip    => \%skip,
		($opt->{n}) ? () : 
		(
		    recurse => 1,
		    first   => 1,
		),
	);

	%skip = map { (&$inc_find($_) => 1) } @exclude;

	my $add_deps = _obj_function($fe, 'add_deps');

	&$add_deps
	(
		rv      => \%map,
		modules => \@modules,
		skip    => \%skip,
	);

	my %text;

	$text{$_} = ($map{$_}{type} =~ /^(?:module|autoload)$/) for keys %map;
	$map{$_}  = $map{$_}{file} for keys %map;

	$self->{pack_attrib}{text} = \%text;
	$self->{pack_attrib}{map} = \%map;
	$self->{pack_attrib}{shared_libs} = \@SharedLibs;


	my $size = 0;
	my $old_member;

	if ($opt->{'m'} and -e $par_file)
	{
		my $tmpzip = Archive::Zip->new();
		$tmpzip->read($par_file);

		if ($old_member = $tmpzip->memberNamed( 'MANIFEST' ))
		{
		    $full_manifest->{$_} = [ "file", $_ ] 
								for (grep /^\S/, split(/\n/, $old_member->contents));
		    $dep_manifest->{$_} = [ "file", $_ ] 
								for (grep /^\S/, split(/\n/, $old_member->contents));
		}
		else 
		{
		    $old_member = 1;
		}
		$self->{pack_attrib}{old_member} = $old_member;
	}

	my $verbatim = ($ENV{PAR_VERBATIM} || 0);

	my $mod_filter = PAR::Filter->new
						(
							'PatchContent',
							@{ $opt->{F} || ($verbatim ? [] : ['PodStrip']) },
						);

	foreach my $pfile (sort grep length $map{$_}, keys %map) 
	{
		next if (!$opt->{B} and ($map{$pfile} eq "$Config{privlib}/$pfile")
		                  or $map{$pfile} eq "$Config{archlib}/$pfile");

#		next unless $zip;  # WHY IS THIS HERE??

		$self->_vprint(2, "... adding $map{$pfile} as ${root}lib/$pfile");

		if ($text{$pfile} or $pfile =~ /utf8_heavy\.pl$/i)
		{
		    my $content_ref = $mod_filter->apply($map{$pfile}, $pfile);

			$full_manifest->{$root."lib/$pfile"} = [ "string", $content_ref ];
			$dep_manifest->{$root."lib/$pfile"} =  [ 'string', $content_ref ];

#		    $zip->addString( $content_ref => $root."lib/$pfile", %zip_args );
		}
		else 
		{
#		    $zip->addFile($map{$pfile} => $root."lib/$pfile");

			$full_manifest->{$root."lib/$pfile"} = [ "file", $map{$pfile} ];
			$dep_manifest->{$root."lib/$pfile"} =  [ "file", $map{$pfile} ];
		}
	}

	my $script_filter;
	$script_filter = PAR::Filter->new( @{ $opt->{f} } ) if ($opt->{f});

	my $in;
	foreach my $in (@$input) 
	{
		my $name = basename($in);

		if ($script_filter) 
		{
			my $string = $script_filter->appliy($in, $name);

			$full_manifest->{"script/$name"} = [ "string", $string ];
			$dep_manifest->{"script/$name"} = [ "string", $string ];

#		    $zip->addString
#			(
#		        $script_filter->apply($in, $name) => "script/$name",
#		        %zip_args,
#		    );
		}
		else 
		{
			$full_manifest->{"script/$name"} = [ "file", $in ];
			$dep_manifest->{"script/$name"}  = [ "file", $in ];

#		    $zip->addFile( $in => "script/$name");
		}
	}

	my $shlib = "shlib/$Config{archname}";

	foreach my $in (@SharedLibs) 
	{
		next unless -e $in;
		my $name = basename($in);

#		$zip->addFile($in => "$shlib/$name");
		$dep_manifest->{"$shlib/$name"} = [ "file", $in ];
		$full_manifest->{"$shlib/$name"} = [ "file", $in ];
	}

	foreach my $in (@data) 
	{
		unless (-r $in and !-d $in) 
		{
		    warn "'$in' does not exist or is not readable; skipping\n";
		    next;
		}
		$full_manifest->{$in}++;
		$dep_manifest->{$in}++;
	}

	if (@$input)
	{
		my $string = (@$input == 1)? 
					_main_pl_single("script/" . basename($input->[0]))
				:	_main_pl_multi();
		
		$full_manifest->{"script/main.pl"} = [ 'string', $string ];
		$dep_manifest->{"script/main.pl"} = [ 'string', $string ];
	}

	$full_manifest->{'MANIFEST'} = [ 'string', "<<placeholder>>" ];
	$full_manifest->{'META.yml'} = [ 'string', "<<placeholder>>" ];

	$dep_manifest->{'MANIFEST'}  = [ 'string', "<<placeholder>>" ];
	$dep_manifest->{'META.yml'}  = [ 'string', "<<placeholder>>" ];

	return($dep_manifest);
}

sub full_manifest_hash
{
	my ($self) = @_;

	$self->pack_manifest_hash();
	return($self->{full_manifest});
}

sub full_manifest
{
	my ($self) = @_;

	$self->pack_manifest_hash();
	my $mh = $self->{full_manifest};
	return( [ sort keys(%$mh) ]);
}

sub add_manifest_hash
{
	my ($self) = @_;
	return($self->{add_manifest}) if ($self->{add_manifest});
	my $mh = $self->{add_manifest} = {};

	my $ma = $self->_add_manifest();

	my $elt;

	foreach $elt (@$ma)
	{
		if (-f $elt->[0])
		{
			$mh->{$elt->[1]} = [ 'file', $elt->[0] ];
		}
		elsif (-d $elt->[0])
		{
			my ($f, $a) = _expanddir(@$elt);

			my $xx;
			for ($xx = 0; $xx < @$f; $xx++) 
			{ 
				$mh->{$a->[$xx]} = [ 'file', $f->[$xx] ]; 
			}
		}
	}
	return($mh);
}

sub _add_manifest
{
	my ($self) = @_;

	my $opt = $self->{options};
	my $return = [];
	my $extra = [];

	$extra = $opt->{a} if ($opt->{a});
	if ($opt->{A})
	{
		my $fh;
		open($fh, $opt->{A}) || _die($self, "Can't open file $opt->{A}: $!\n");

		my $line;
		while ($line = <$fh>) { chomp($line); push(@$extra, $line); }
	}

	my $f;
	foreach $f (@$extra) 
	{ 
		if ($f =~ m" ")
		{
			my @split = split(m" +", $f); 
			push(@$return, [ @split ]);
		}
		else
		{
			push(@$return, [ $f, $f ]);
		}
	}
	return($return);
}

sub add_manifest
{
	my ($self) = @_;
	my $mh = $self->add_manifest_hash();

	my @ma = sort keys(%$mh);
	return(\@ma);
}


sub _add_pack_manifest
{
	my ($self) = @_;

	my $par_file = $self->{par_file};
	my $opt = $self->{options};

	$self->{zip} ||= Archive::Zip->new;
	my $zip = $self->{zip};

	my $input = $self->{input};

	$self->_vprint(1, "Writing PAR on $par_file");

	$zip->read($par_file) if ($opt->{'m'} and -e $par_file);

 	my $pack_manifest = $self->pack_manifest_hash();

	my $map  = 			$self->{pack_attrib}{'map'};
	my $root = 			$self->{pack_attrib}{root};
	my $shared_libs = 	$self->{pack_attrib}{shared_libs};

	$zip->addDirectory('', substr($root, 0, -1)) if ($root and %$map and $] >= 5.008);
	$zip->addDirectory('', $root . 'lib') if( %$map and $] >= 5.008);

	my $shlib = "shlib/$Config{archname}";
	$zip->addDirectory('', $shlib) if (@$shared_libs and $] >= 5.008);

	my @tmp_input = @$input;
	@tmp_input = grep !/\.pm\z/i, @tmp_input;

	$zip->addDirectory('', 'script') if (@tmp_input and $] >= 5.008);

	my $in;
	foreach $in (sort keys(%$pack_manifest))
	{
		my $value = $pack_manifest->{$in};
		$self->_addfile($zip, $in, $value);
	}

}

sub _make_manifest
{
}

sub dep_files
{
	my ($self) = @_;

	my $dm = $self->{dep_manifest};
	return( [ keys (%$dm) ] ) if ($dm);


}

sub _addfile
{
	my ($self, $zip, $in, $value, $manifest) = @_;

	my $oldsize = $self->{pack_attrib}{old_size};
	my $full_manifest = $self->{full_manifest};

	if ($value->[0] eq "file")  # file
	{
		my $fn = $value->[1];

		if (-d $fn)
		{
			my ($files, $aliases) = _expanddir($fn, $in);

			$self->_vprint( 1, "... adding $fn as $in\n");

			my $xx;
			for ($xx = 0; $xx < @$files; $xx++) 
			{
				$self->_vprint( 1, "... adding $fn as $in\n");

				$full_manifest->{ $aliases->[$xx] } = [ 'file', $files->[$xx] ];
				$manifest->{$aliases->[$xx]} = [ 'file', $files->[$xx] ];

				$oldsize += -s $files->[$xx];
				$zip->addFile($files->[$xx], $aliases->[$xx]); 
			}
		}
		else
		{

			$self->_vprint( 1, "... adding $fn as $in\n");

			$oldsize += -s $fn;
			$zip->addFile($fn => $in );
		}
	}
	else
	{
		my $str = $value->[1];
		$oldsize += length($str);

		$self->_vprint( 1, "... adding <string> as $in");
		$zip->addString($str => $in, %_zip_args);
	}

	$self->{pack_attrib}{old_size} = $oldsize;
}

sub _expanddir
{
	my ($fn, $in) = @_;
	my (@return, @aliasreturn);

	find
	( 
		{ 
			wanted => sub {  push(@return, $File::Find::name) if -f; },
			follow_fast => 1  
		} , $fn 
	);
	@aliasreturn = @return;

	grep(s"^$fn"$in", @aliasreturn);

	return(\@return, \@aliasreturn);
}

sub _die 
{
	my ($self, @args) = @_;

	my $opt = $self->{options};
	my $logfh = $self->{logfh};

	$logfh->print(@args) if ($opt->{L});
	die @args;
}

sub _name2moddata 
{
	my ($name, $mod, $dat) = @_;

	if ($name =~ /^[\w:]+$/) 
	{
		$name =~ s/::/\//g;
		push @$mod, "$name.pm";
	}
	elsif ($name =~ /\.(?:pm|ix|al)$/i) 
	{
		push @$mod, $name;
	}
	else 
	{
		push @$dat, $name;
	}
}

sub _par_to_exe 
{
	my ($self) = @_;

	my $PARL;
	my $opt = $self->{options};
	my $output = $self->{output};
	my $dynperl = $self->{dynperl};
	my $par_file = $self->{par_file};

	my $parl = 'parl';
	my $buf;

	$parl = 'parldyn' if ($opt->{d} and $dynperl);
	$parl .= $Config{_exe};

	$parl = 'par.pl' if ($opt->{P});
	$PARL ||= _can_run($parl, $opt->{P}) or _die("Can't find par loader");

	my $orig_parl = $PARL;

	my $do_unlink;

	if 
	(
		!$opt->{p} and $opt->{i} and $^O eq 'MSWin32' and Win32::IsWinNT() 
		and my $replace_icon = _can_run("replaceicon.exe")
	) 
	{
		my $cfh;

		local $/;

		open _FH, $PARL or die $!;
		binmode(_FH);

		($cfh, $PARL) = tempfile("parlXXXX", SUFFIX => ".exe"); 

		binmode($cfh);
		print $cfh <_FH>;
		close $cfh;

		$self->_vprint( 1, "Adding icon to $output");
		my $cmd = join
					(
		    			' ', map Win32::GetShortPathName($_),
		    			$replace_icon, $PARL, $opt->{i}
					);

		`$cmd`;

		seek _FH, -8, 2;
		read _FH, $buf, 8;

		die unless $buf eq "\nPAR.pm\n";

		seek _FH, -12, 2;
		read _FH, $buf, 4;
		seek _FH, -12 - unpack("N", $buf), 2;

		open $cfh, ">>", $PARL or die $!;
		binmode($cfh);
		print $cfh <_FH>;
		close $cfh;

		$do_unlink = 1;
	}

	my @args = ('-B', "-O$output", $par_file);

	unshift @args, '-q' unless ($opt->{v});

	if ($opt->{P})
	{
		unshift @args, $PARL;
		$PARL = $^X;
	}
	$self->_vprint( 0, "Running $PARL @args");

	system($PARL, @args);

	if ($opt->{g} and $^O eq 'MSWin32') 
	{
		$self->_vprint( 1, "Fixing $output to remove its console window");

		_strip_console($output);

		if ($dynperl and !$opt->{d}) 
		{
		    # we have a static.exe that needs taking care of.

		    open _FH, $orig_parl or die $!;
		    binmode _FH;
		    seek _FH, -8, 2;
		    read _FH, $buf, 8;

		    die unless $buf eq "\nPAR.pm\n";

		    seek _FH, -12, 2;
		    read _FH, $buf, 4;
		    seek _FH, -12 - unpack("N", $buf) - 4, 2;
		    read _FH, $buf, 4;

		    strip_console($output, unpack("N", $buf));
		}
	}

	if ($do_unlink) 
	{
		unlink($PARL);
		unlink("$PARL.bak");
	}
}

sub _strip_console 
{
	my $file = shift;
	my $preoff = shift || 0;

	my ($record, $magic, $signature, $offset, $size);

	open my $exe, "+< $file" or die "Cannot open $file: $!\n";
	binmode $exe;
	seek $exe, $preoff, 0;

	# read IMAGE_DOS_HEADER structure
	read $exe, $record, 64;
	($magic, $offset) = unpack "Sx58L", $record;

	die "$file is not an MSDOS executable file.\n"
		unless $magic == 0x5a4d; # "MZ"

	# read signature, IMAGE_FILE_HEADER and first WORD of IMAGE_OPTIONAL_HEADER
	seek $exe, $preoff + $offset, 0;
	read $exe, $record, 4+20+2;

	($signature,$size,$magic) = unpack "Lx16Sx2S", $record;

	die "PE header not found" unless $signature == 0x4550; # "PE\0\0"

	die "Optional header is neither in NT32 nor in NT64 format"
		unless ($size == 224 && $magic == 0x10b) || # IMAGE_NT_OPTIONAL_HDR32_MAGIC
		       ($size == 240 && $magic == 0x20b);   # IMAGE_NT_OPTIONAL_HDR64_MAGIC

	# Offset 68 in the IMAGE_OPTIONAL_HEADER(32|64) is the 16 bit subsystem code

	seek $exe, $preoff + $offset+4+20+68, 0;
	print $exe pack "S", 2; # IMAGE_WINDOWS
	close $exe;
}

sub _obj_function
{
	my ($module_or_class, $func_name) = @_;

	my $func;
	if (ref($module_or_class))
	{
		$func = $module_or_class->can($func_name);
		die "SYSTEM ERROR: $func_name does not exist in $module_or_class\n" if (!$func);

		if (%$module_or_class) # hack because Module::ScanDeps isn't really object.
		{
			my $closure = sub { &$func($module_or_class, @_) };
			return($closure);
		}
		else
		{
			return($func);
		}
	}
	else
	{
		$func = $module_or_class->can($func_name);
		return($func);
	}
}	

sub _vprint ($@) 
{
	my $self = shift;
	my $level = shift;
	my $msg = "@_";

	my $opt = $self->{options};
	my $logfh = $self->{logfh};

	$msg .= "\n" unless substr($msg, -1) eq "\n";

	my $verb = $ENV{PAR_VERBOSE} || 0;
	if ($opt->{v} > $level || $verb > $level)
	{
		print        "$0: $msg" if (!$opt->{L});
		print $logfh "$0: $msg" if  ($opt->{L});
	}
}

sub _check_par 
{
	my ($self, $file) = @_;

	open(my $handle, "<", $file) or _die($self, "XXX: Can't open $file: $!");

	binmode($handle);
	local $/ = \4;
	return (<$handle> eq "PK\x03\x04");
}

sub _find_shlib 
{
	my $file = shift;
	my $script_name = shift;

	return $file if -e $file;

	if (not exists $ENV{$Config{ldlibpthname}}) {
		print "Can't find $file. Environment variable " .
		"$Config{ldlibpthname} does not exist.\n";
		return;
	}

	for my $dir 
	(
		File::Basename::dirname($0),
		split(/\Q$Config{path_sep}\E/, $ENV{$Config{ldlibpthname}})
	) 
	{
		my $abs = File::Spec->catfile($dir, $file);
		return $abs if -e $abs;
		$abs = File::Spec->catfile($dir, "$file.$Config{dlext}");
		return $abs if -e $abs;
	}

	# be extra magical and prepend "lib" to the filename
	return _find_shlib("lib$file", $script_name) unless $file =~ /^lib/;
}

sub _can_run 
{
	my ($command, $no_exec) = @_;

	for my $dir 
	(
		File::Basename::dirname($0),
		split(/\Q$Config{path_sep}\E/, $ENV{PATH})
	) 
	{
		my $abs = File::Spec->catfile($dir, $command);
		return $abs if $no_exec or $abs = MM->maybe_command($abs);
	}
	return;
}

sub _main_pl_multi 
{
	return << '__MAIN__';
my $file = $0;
my $zip = $PAR::LibCache{$0} || Archive::Zip->new(__FILE__);
$file =~ s/^.*[\/\\]//;
$file =~ s/\.[^.]*$//i ;
my $member = eval { $zip->memberNamed($file) }
		|| $zip->memberNamed("$file.pl")
		|| $zip->memberNamed("script/$file")
		|| $zip->memberNamed("script/$file.pl")
	or die qq(Can't open perl script "$file": No such file or directory);
PAR::_run_member($member, 1);

__MAIN__
}

sub _main_pl_single 
{
	my $file = shift;
	return << "__MAIN__";
my \$zip = \$PAR::LibCache{\$0} || Archive::Zip->new(__FILE__);
my \$member = eval { \$zip->memberNamed('$file') }
	or die qq(Can't open perl script "$file": No such file or directory (\$zip));
PAR::_run_member(\$member, 1);

__MAIN__
}

sub DESTROY 
{
	my ($self) = @_;

	my $par_file = $self->{par_file};
	my $opt = $self->{options};

	unlink $par_file if ($par_file && !$opt->{S} && !$opt->{p});
}


__END__

=head1 NAME

pp - Perl Packager

=head1 SYNOPSIS

B<pp> S<[ B<-BILMSVXdeghilmoprsv> ]> S<[ I<parfile> | I<scriptfile> ]>...

=head1 OPTIONS

	% pp hello                  # Pack 'hello' into executable 'a.out'
	% pp -o hello hello.pl      # Pack 'hello.pl' into executable 'hello'

	% pp -o foo foo.pl bar.pl   # Pack 'foo.pl' and 'bar.pl' into 'foo'
	% ./foo                     # Run 'foo.pl' inside 'foo'
	% mv foo bar; ./bar         # Run 'bar.pl' inside 'foo'
	% mv bar baz; ./baz         # Error: Can't open perl script "baz"

	% pp -p file                # Creates a PAR file, 'file.par'
	% pp -o hello file.par      # Pack 'file.par' to executable 'hello'
	% pp -S -o hello file       # Combine the two steps above

	% pp -p -o out.par file     # Creates 'out.par' from 'file'
	% pp -B -p -o out.par file  # same as above, but bundles core modules
	% pp -P -o out.pl file      # Creates 'out.pl' from 'file'
	% pp -B -p -o out.pl file   # same as above, but bundles core modules
		                        # (-B is assumed when making executables)

	% pp -e 'print 123'         # Pack a one-liner into 'a.out'
	% pp -p -e 'print 123'      # Creates a PAR file 'a.par'
	% pp -P -e 'print 123'      # Creates a perl script 'a.pl'

	% pp -c hello               # Check dependencies from "perl -c hello"
	% pp -x hello               # Check dependencies from "perl hello"
	% pp -n -x hello            # same as above, but skips static scanning

	% pp -I /foo hello          # Extra paths (notice space after -I)
	% pp -M Foo::Bar hello      # Extra modules (notice space after -M)
	% pp -M abbrev.pl hello     # Extra files under @INC
	% pp -X Foo::Bar hello      # Exclude modules (notice space after -X)

	% pp -r hello               # Pack 'hello' into 'a.out', runs 'a.out'
	% pp -r hello a b c         # Pack 'hello' into 'a.out', runs 'a.out'
		                        # with arguments 'a b c' 

	% pp hello --log=c          # Pack 'hello' into 'a.out', logs
		                        # messages into 'c'

	# Pack 'hello' into a console-less 'out.exe' with icon (Win32 only)
	% pp --gui --icon hello.ico -o out.exe hello

=head1 DESCRIPTION

F<pp> creates standalone executables from Perl programs, using the
compressed packager provided by L<PAR>, and dependency detection
heuristics offered by L<Module::ScanDeps>.  Source files are compressed
verbatim without compilation.

You may think of F<pp> as "F<perlcc> that works without hassle". :-)

A GUI interface is also available as the F<tkpp> command.

It does not provide the compilation-step acceleration provided by
F<perlcc> (however, see B<-f> below for byte-compiled, source-hiding
techniques), but makes up for it with better reliability, smaller
executable size, and full retrieval of original source code.

When a single input program is specified, the resulting executable will
behave identically as that program.  However, when multiple programs
are packaged, the produced executable will run the one that has the
same basename as C<$0> (i.e. the filename used to invoke it).  If
nothing matches, it dies with the error C<Can't open perl script "$0">.

On Microsoft Windows platforms, F<a.exe> is used instead of F<a.out>
as the default executable name.

=head1 OPTIONS

Options are available in a I<short> form and a I<long> form.  For
example, the three lines below are all equivalent:

	% pp -o output.exe input.pl
	% pp --output output.exe input.pl
	% pp --output=output.exe input.pl

=over 4

=item B<-M>, B<--add>=I<MODULE>|I<FILE>

Add the specified module into the package, along with its dependencies.
Also accepts filenames relative to the C<@INC> path; i.e. C<-M
Module::ScanDeps> means the same thing as C<-M Module/ScanDeps.pm>.

If I<FILE> does not have a C<.pm>/C<.ix>/C<.al> extension, it will not
be scanned for dependencies, and will be placed under C</> instead of
C</lib/> inside the PAR file.

=item B<-B>, B<--bundle>

Bundle core modules in the resulting package.  This option is enabled
by default, except when C<-p> or C<-P> is specified.

=item B<-C>, B<--clean>

Clean up temporary files extracted from the application at runtime.
By default, these files are cached in the temporary directory; this
allows the program to start up faster next time.

=item B<-d>, B<--dependent>

Reduce the executable size by not including a copy of perl interpreter.
Executables built this way will need a separate F<perl5x.dll>
or F<libperl.so> to function correctly.  This option is only available
if perl is built as a shared library.

=item B<-c>, B<--compile>

Run C<perl -c inputfile> to determine additonal run-time dependencies.

=item B<-e>, B<--eval>=I<STRING>

Package a one-liner, much the same as C<perl -e '...'>

=item B<-x>, B<--execute>

Run C<perl inputfile> to determine additonal run-time dependencies.

=item B<-X>, B<--exclude>=I<MODULE>

Exclude the given module from the dependency search patch and from the
package.

=item B<-f>, B<--filter>=I<FILTER>

Filter source script(s) with a L<PAR::Filter> subclass.  You may specify
multiple such filters.

If you wish to hide the source code from casual prying, this will do:

	% pp -f Bleach source.pl

Users with Perl 5.8.1 and above may also try out the experimental
byte-compiling filter, which will strip away all comments and indents:

	% pp -f Bytecode source.pl

=item B<-g>, B<--gui>

Build an executable that does not have a console window. This option is
ignored on non-MSWin32 platforms or when C<-p> is specified.

=item B<-h>, B<--help>

Show basic usage information.

=item B<-i>, B<--icon>=I<FILE>

Specify an icon file for the executable. This option is ignored on
non-MSWin32 platforms or when C<-p> is specified.

=item B<-N>, B<--info>=I<KEY=VAL>

Add additional information for the packed file, both in C<META.yml>
and in the executable header (if applicable).  The name/value pair is
separated by C<=>.  You may specify C<-N> multiple times.

For Win32 executables, these special C<KEY> names are recognized:

	Comments        CompanyName     FileDescription FileVersion
	InternalName    LegalCopyright  LegalTrademarks OriginalFilename
	ProductName     ProductVersion

This feature is currently unimplemented.

=item B<-I>, B<--lib>=I<DIR>

Add the given directory to the perl library file search path.

=item B<-l>, B<--link>=I<FILE>|I<LIBRARY>

Add the given shared library (a.k.a. shared object or DLL) into the
packed file.  Also accepts names under library paths; i.e.
C<-l ncurses> means the same thing as C<-l libncurses.so> or
C<-l /usr/local/lib/libncurses.so> in most Unixes.

=item B<-L>, B<--log>=I<FILE>

Log the output of packaging to a file rather than to stdout.

=item B<-F>, B<--modfilter>=I<FILTER>

Filter included perl module(s) with a L<PAR::Filter> subclass.
You may specify multiple such filters.

=item B<-m>, B<--multiarch>

Build a multi-architecture PAR file.  Implies B<-p>.

=item B<-n>, B<--noscan>

Skip the default static scanning altogether, using run-time
dependencies from B<-c> or B<-x> exclusively.

=item B<-o>, B<--output>=I<FILE>

File name for the final packaged executable.

=item B<-p>, B<--par>

Create PAR archives only; do not package to a standalone binary.

=item B<-P>, B<--perlscript>

Create stand-alone perl script; do not package to a standalone binary.

=item B<-r>, B<--run>

Run the resulting packaged script after packaging it.

=item B<-S>, B<--save>

Do not delete generated PAR file after packaging.

=item B<-s>, B<--sign>

Cryptographically sign the generated PAR or binary file using
L<Module::Signature>.

=item B<-v>, B<--verbose>[=I<NUMBER>]

Increase verbosity of output; I<NUMBER> is an integer from C<0> to C<5>,
C<5> being the most verbose.  Defaults to C<1> if specified without an
argument.

=item B<-V>, B<--version>

Display the version number and copyrights of this program.

=back

=head1 ENVIRONMENT

=over 4

=item PP_OPTS

Command-line options (switches).  Switches in this variable are taken
as if they were on every F<pp> command line.

=back

=head1 NOTES

Here are some recipes showing how to utilize F<pp> to bundle
F<source.pl> with all its dependencies, on target machines with
different expected settings:

=over 4

=item Stand-alone setup

	% pp -o packed.exe source.pl        # makes packed.exe
	# Now, deploy 'packed.exe' to target machine...
	$ packed.exe                        # run it

=item Perl interpreter only, without core modules:

	% pp -B -P -o packed.pl source.pl   # makes packed.exe
	# Now, deploy 'packed.exe' to target machine...
	$ perl packed.pl                    # run it

=item Perl with core module installed:

	% pp -P -o packed.pl source.pl      # makes packed.exe
	# Now, deploy 'packed.pl' to target machine...
	$ perl packed.pl                    # run it

=item Perl with PAR.pm and its dependencies installed:

	% pp -p source.pl                   # makes source.par
	% echo "use PAR 'source.par';" > packed.pl;
	% cat source.pl >> packed.pl;       # makes packed.pl
	# Now, deploy 'source.par' and 'packed.pl' to target machine...
	$ perl packed.pl                    # run it

=back

Note that even if your perl was built with a shared library, the
'Stand-alone setup' above will I<not> need a separate F<perl5x.dll>
or F<libperl.so> to function correctly.  Use C<--dependent> if you
are willing to ship the shared library with the application, which
can significantly reduce the executable size.

=head1 SEE ALSO

L<tkpp>, L<par.pl>, L<parl>, L<perlcc>

L<PAR>, L<Module::ScanDeps>

=head1 ACKNOWLEDGMENTS

Simon Cozens, Tom Christiansen and Edward Peschko for writing
F<perlcc>; this program try to mimic its interface as close
as possible, and copied liberally from their code.

Jan Dubois for writing the F<exetype.pl> utility, which has been
partially adapted into the C<-g> flag.

Mattia Barbon for providing the C<myldr> binary loader code.

Jeff Goff for suggesting the name C<pp>.

=head1 AUTHORS

Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>

L<http://par.perl.org/> is the official PAR website.  You can write
to the mailing list at E<lt>par@perl.orgE<gt>, or send an empty mail to
E<lt>par-subscribe@perl.orgE<gt> to participate in the discussion.

Please submit bug reports to E<lt>bug-par@rt.cpan.orgE<gt>.

=head1 COPYRIGHT

Copyright 2002, 2003, 2004 by Autrijus Tang E<lt>autrijus@autrijus.orgE<gt>.

Neither this program nor the associated L<parl> program impose any
licensing restrictions on files generated by their execution, in
accordance with the 8th article of the Artistic License:

	"Aggregation of this Package with a commercial distribution is
	always permitted provided that the use of this Package is embedded;
	that is, when no overt attempt is made to make this Package's
	interfaces visible to the end user of the commercial distribution.
	Such use shall not be construed as a distribution of this Package."

Therefore, you are absolutely free to place any license on the resulting
executable, as long as the packed 3rd-party libraries are also available
under the Artistic License.

This program is free software; you can redistribute it and/or modify it
under the same terms as Perl itself.

See L<http://www.perl.com/perl/misc/Artistic.html>

=cut
