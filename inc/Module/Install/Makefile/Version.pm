# $File: //depot/cpan/Module-Install/lib/Module/Install/Makefile/Version.pm $ $Author: autrijus $
# $Revision: #2 $ $Change: 1186 $ $DateTime: 2003/03/01 04:29:41 $

package Module::Install::Makefile::Version;
$VERSION = '0.01';

sub determine_VERSION {
    my ($self, $ARGS) = @_;
    my $VERSION = '';
    my @modules = (glob('*.pm'), grep {/\.pm$/i} $self->find_files('lib'));
    if (@modules == 1) {
        eval {
            $VERSION = ExtUtils::MM_Unix->parse_version($modules[0]);
        };
        print STDERR $@ if $@;
    }
    elsif (my $file = "lib/$ARGS->{NAME}.pm") {
	$file =~ s!-!/!g;
	$VERSION = ExtUtils::MM_Unix->parse_version($file) if -f $file;
    }
    die <<END unless length($VERSION);
Can't determine a VERSION for this distribution.
Please pass a VERSION parameter to the WriteMakefile function in Makefile.PL.
END
#'
    $ARGS->{VERSION} = $VERSION;
}

1;
