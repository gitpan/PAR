# $File: //depot/cpan/Module-Install/lib/Module/Install/Fetch.pm $ $Author: autrijus $
# $Revision: #5 $ $Change: 1289 $ $DateTime: 2003/03/07 08:25:20 $ vim: expandtab shiftwidth=4

package Module::Install::Fetch;
use base 'Module::Install::Base';

$VERSION = '0.01';

sub get_file {
    my ($self, %args) = @_;
    my ($scheme, $host, $path, $file) = 
        $args{url} =~ m|^(\w+)://([^/]+)(.+)/(.+)| or return;

    return unless $scheme eq 'ftp';

    $|++;
    print "Fetching '$file' from $host... ";

    unless (eval { require Socket; Socket::inet_aton($host) }) {
        warn "'$host' resolve failed!\n";
        return;
    }

    require Cwd;
    my $dir = Cwd::getcwd();
    chdir $args{local_dir} or return if exists $args{local_dir};

    if (eval { require Net::FTP; 1 }) {
        # use Net::FTP to get pass firewall
        my $ftp = Net::FTP->new($host, Passive => 1, Timeout => 600);
        $ftp->login("anonymous", 'anonymous@example.com');
        $ftp->cwd($path);
        $ftp->binary;
        $ftp->get($file) or (warn("$!\n"), return);
        $ftp->quit;
    }
    elsif (my $ftp = $self->can_run('ftp')) {
        # no Net::FTP, fallback to ftp.exe
        require FileHandle;
        my $fh = FileHandle->new;

        local $SIG{CHLD} = 'IGNORE';
        unless ($fh->open("|$ftp -n")) {
            warn "Couldn't open ftp: $!\n";
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
        warn "No working 'ftp' program available!\n";
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
