#line 1 "inc/Module/Install/PAR.pm - /usr/local/lib/perl5/site_perl/5.8.0/Module/Install/PAR.pm"
# $File: //depot/cpan/Module-Install/lib/Module/Install/PAR.pm $ $Author: autrijus $
# $Revision: #26 $ $Change: 1555 $ $DateTime: 2003/05/25 11:48:33 $ vim: expandtab shiftwidth=4

package Module::Install::PAR;
use Module::Install::Base; @ISA = qw(Module::Install::Base);

sub par_base {
    my ($self, $base, $file) = @_;
    my $class = ref($self);
    my $inc_class = join('::', @{$self->_top}{qw(prefix name)});
    my $ftp_base;

    if (defined $base and length $base) {
        if ($base =~ m!^(([A-Z])[A-Z])[-_A-Z]+\Z!) {
            $self->{mailto} = "$base\@cpan.org";
            $ftp_base = "ftp://ftp.cpan.org/pub/CPAN/authors/id/$2/$1/$base";
            $base = "http://www.cpan.org/authors/id/$2/$1/$base";
        }
        elsif ($base !~ m!^(\w+)://!) {
            die "Cannot recognize path '$base'; please specify an URL or CPAN ID";
        }
        $base .= '/' unless $base =~ m!/\Z!;
        $ftp_base .= '/' unless $ftp_base =~ m!/\Z!;
    }

    require Config;
    my $suffix = "$Config::Config{archname}-$Config::Config{version}.par";

    unless ($file ||= $self->{file}) {
        my $name    = $self->name or return;
        my $version = $self->version or return;
        $name =~ s!::!-!g;
        $self->{file} = $file = "$name-$version-$suffix";
    }

    my $perl = $^X;
    $perl = Win32::GetShortPathName($perl)
        if $perl =~ / / and defined &Win32::GetShortPathName;

    $self->preamble(<<"END") if $base;
# --- $class section:

all ::
\t\@$perl -M$inc_class -e \"extract_par(q($file))\"

END

    $self->postamble(<<"END");
# --- $class section:

$file: all test
\t\@\$(PERL) -M$inc_class -e \"make_par(q($file))\"

par :: $file
\t\@\$(NOOP)

par-upload :: $file
\tcpan-upload -verbose $file

END

    $self->{url} = $base;
    $self->{ftp_url} = $ftp_base;
    $self->{suffix} = $suffix;

    return $self;
}

sub fetch_par {
    my ($self, $url, $file, $quiet) = @_;
    $url = $self->{url} || $self->par_base($url)->{url};
    $ftp_url = $self->{ftp_url};
    $file ||= $self->{file};

    return $file if -f $file or $self->get_file(
        url     => "$url$file",
        ftp_url => "$ftp_url$file"
    );

    require Config;
    print << "END" if $self->{mailto} and !$quiet;
*** No installation package available for your architecture.
However, you may wish to generate one with '$Config::Config{make} par' and send
it to <$self->{mailto}>, so other people on the same platform
can benefit from it.
*** Proceeding with normal installation...
END
    return;
}

sub extract_par {
    my ($self, $file) = @_;
    return unless -f $file;

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
        return unless $zip->read($file) == Archive::Zip::AZ_OK()
                  and $zip->extractTree('', 'blib/') == Archive::Zip::AZ_OK();
    }
    elsif ($self->can_run('unzip')) {
        return if system(unzip => $file, qw(-d blib));
    }

    local *PM_TO_BLIB;
    open PM_TO_BLIB, '> pm_to_blib' or die $!;
    close PM_TO_BLIB;
}

sub make_par {
    my ($self, $file) = @_;
    unlink $file if -f $file;

    my @files;
    open MANIFEST, ">blib/MANIFEST" or die $!;
    open META, ">blib/META.yml" or die $!;
    
    require File::Find;
    File::Find::find( sub {
        (-r && !-d) and push ( @files, substr($File::Find::name, 5) );
    } , 'blib' );

    print MANIFEST join("\n", '    <!-- accessible as jar:file:///NAME.par!/MANIFEST in compliant browsers -->', (sort @files), q(    # <html><body onload="var X=document.body.innerHTML.split(/\n/);var Y='<iframe src=&quot;META.yml&quot; style=&quot;float:right;height:40%;width:40%&quot;></iframe><ul>';for(var x in X){if(!X[x].match(/^\s*#/)&&X[x].length)Y+='<li><a href=&quot;'+X[x]+'&quot;>'+X[x]+'</a>'}document.body.innerHTML=Y">));
    close MANIFEST;

    print META << "YAML";
build_requires: {}
conflicts: {}
dist_name: $file
distribution_type: par
dynamic_config: 0
generated_by: 'Module::Install version $Module::Install::VERSION'
license: unknown
YAML
    close META;

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
        $zip->addTree( 'blib', '' );
        $zip->writeToFileNamed( $file ) == AZ_OK or die $!;
    }
    elsif ($self->can_run('zip')) {
        mkdir('blib', 0777);
        chdir('blib');
        system(qw(zip -r), "../$file", '.') and die $!;
        chdir('..');
    }

    unlink "blib/MANIFEST";
    unlink "blib/META.yml";

    require File::Spec;
    my $pathname = File::Spec->rel2abs($file);
    if ($^O eq 'MSWin32') {
        $pathname =~ s!\\!/!g;
        $pathname =~ s!:!|!g;
    };
    print << ".";
Successfully created binary distribution '$file'.
Its contents are accessible in compliant browsers as:
    jar:file://$pathname!/MANIFEST
.
}

1;
