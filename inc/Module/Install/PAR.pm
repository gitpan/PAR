# $File: //depot/cpan/Module-Install/lib/Module/Install/PAR.pm $ $Author: autrijus $
# $Revision: #15 $ $Change: 1337 $ $DateTime: 2003/03/09 06:07:19 $ vim: expandtab shiftwidth=4

package Module::Install::PAR;
use base 'Module::Install::Base';

sub par_base {
    my ($self, $base, $file) = @_;
    my $class = join('::', @{$self->_top}{qw(prefix name)});

    if (defined $base and length $base) {
        if ($base =~ m!^(([A-Z])[A-Z])[-_A-Z]+\Z!) {
            $self->{mailto} = "$base\@cpan.org";
            $base = "ftp://ftp.cpan.org/pub/CPAN/authors/id/$2/$1/$base";
        }
        elsif ($base !~ m!^(\w+)://!) {
            die "Cannot recognize path '$base'; please specify an URL or CPAN ID";
        }
        $base .= '/' unless $base =~ m!/\Z!;
    }

    require Config;
    my $suffix = "$Config::Config{archname}-$Config::Config{version}.par";

    unless ($file ||= $self->{file}) {
        my $name    = $self->name or return;
        my $version = $self->version or return;
        $self->{file} = $file = "$name-$version-$suffix";
    }

    $self->preamble(<<"END") if $base;
all ::
\t\@$^X -M$class -e \"extract_par(q($file))\"

END

    $self->postamble(<<"END");
$file: all test
\t\@\$(PERL) -M$class -e \"make_par(q($file))\"

par :: $file
\t\@\$(NOOP)

par-upload :: $file
\tcpan-upload -verbose $file

END

    $self->{url} = $base;
    $self->{suffix} = $suffix;
}

sub fetch_par {
    my ($self, $url, $file, $quiet) = @_;
    $url = $self->{url} || $self->par_base($url);
    $file ||= $self->{file};

    return $file if -f $file or $self->get_file( url => "$url$file" );

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

    if (eval { require Archive::Zip; 1 }) {
        my $zip = Archive::Zip->new;
        $zip->addTree( 'blib', '' );
        $zip->writeToFileNamed( $file ) == AZ_OK or die $!;
    }
    elsif ($self->can_run('zip')) {
        chdir('blib');
        system(qw(zip -r), "../$file", '.') and die $!;
        chdir('..');
    }

    print "Successfully created binary distribution '$file'.\n";
}

1;
