# $File: //depot/cpan/Module-Install/lib/Module/Install/Fetch.pm $ $Author: autrijus $
# $Revision: #1 $ $Change: 1185 $ $DateTime: 2003/03/01 03:47:14 $

package Module::Install::Fetch;
$VERSION = '0.01';

# fetch nmake from Microsoft's FTP site
sub get_file {
    my %args = @_;

    my ($scheme, $host, $path, $file) = 
	$args{url} =~ m|^(\w+)://([^/]+)(.+)/(.+)| or return;

    return unless $scheme eq 'ftp';

    unless (eval { require Socket; Socket::inet_aton($host) }) {
        print "Cannot fetch 'nmake'; '$host' resolve failed!\n";
        return;
    }

    use Cwd;
    my $dir = getcwd;
    chdir $args{local_dir} or return if exists $args{local_dir};

    $|++;
    print "Fetching '$file' from $host. It may take a few minutes... ";

    if (eval { require Net::FTP; 1 }) {
        # use Net::FTP to get pass firewall
        my $ftp = Net::FTP->new($host, Passive => 1, Timeout => 600);
        $ftp->login("anonymous", 'anonymous@example.com');
        $ftp->cwd($path);
        $ftp->binary;
        $ftp->get($file) or die $!;
        $ftp->quit;
    }
    elsif (can_run('ftp')) {
        # no Net::FTP, fallback to ftp.exe
        require FileHandle;
        my $fh = FileHandle->new;

        local $SIG{CHLD} = 'IGNORE';
        unless ($fh->open("|ftp.exe -n")) {
            warn "Couldn't open ftp: $!";
            chdir $dir; return;
        }

        my @dialog = split(/\n/, << ".");
open $host
user anonymous anonymous\@example.com
cd $path
binary
get $file $file
quit
.
        foreach (@dialog) { $fh->print("$_\n") }
        $fh->close;
    }
    else {
        print "Cannot fetch '$file' without a working 'ftp' executable!\n";
        chdir $dir; return;
    }

    return if exists $args{size} and -s $file != $args{size};
    system($args{run}) if exists $args{run};
    unlink($file) if $args{remove};

    print(((!exists $args{check_for} or -e $args{check_for})
	? "done!" : "failed! ($!)"), "\n");
    chdir $dir; return !$?;
}

1;
