# $File: //depot/cpan/Module-Install/lib/Module/Install.pm $ $Author: autrijus $
# $Revision: #9 $ $Change: 1186 $ $DateTime: 2003/03/01 04:29:41 $

package Module::Install;

# Initializing %Def {{{
use strict 'vars';
use vars qw($AUTOLOAD $M $VERSION);

$VERSION = 0.20;

my %Def = (
    version	=> $VERSION,
    package	=> __PACKAGE__,
    prefix	=> "inc",
    dispatcher	=> "Admin",
);
$Def{dir}   = $Def{package};
$Def{dir}   =~ s!::!/!g;
$Def{file}  = "$Def{prefix}/$Def{dir}.pm";
# }}}

sub import {
    my ($pkg, $file, $dir, $inc, $dispatcher)
	= @Def{qw(package file dir prefix dispatcher)};

    if (!-f $file) {
	require "$dir/$dispatcher.pm";
	"$pkg\::$dispatcher"->new(_top => \%Def)->init;
    }

    # Reload ourselves {{{
    if (!$INC{"$dir.pm"}) {
	require Symbol;
	Symbol::delete_package($pkg);

	unshift @INC, $inc;
	delete $INC{$file};
	warn "directly before jumping: $pkg\n";
	require $file;
	goto &{"$pkg\::import"};
    }
    # }}}

    # Set up AUTOLOAD handler {{{
    *{caller(0) . "\::AUTOLOAD"} = sub {
	$AUTOLOAD =~ /([^:]+)$/ or die "Cannot load $AUTOLOAD";
	my $method = $1;
	$M = $pkg->new;
	$M->$method(@_);
    }
    # }}}
}

sub new {
    my ($class, %args) = @_;
    exists $args{$_} or $args{$_} = $Def{$_} for keys %Def;
    bless(\%args, $class);
}

sub AUTOLOAD {
    # the main dispatcher
    my $self = shift;
    my $method = $1 if $AUTOLOAD =~ /([^:]+)$/;
    return if $method eq 'DESTROY';
    $self->call($method, \@_, 0);
}

sub call {
    my ($self, $method, $args, $load_only) = @_;
    $load_only = 1 unless defined $load_only;
    my $obj = $self->load($method, $load_only) or return;
    $obj->$method(@$args);
}

sub load {
    my ($self, $method, $load_only) = @_;
    $M->{_copy}{$method} = !$load_only;

    my $self = $self->{_top} || $self;
    $self->load_extensions unless $self->{extensions};
    foreach my $obj (@{$self->{extensions}}) {
	return $obj if $obj->can($method);
    }

    # nothing found. panic.
    unless (eval { require "$self->{dir}/$self->{dispatcher}.pm"; 1 }) {
	return if $load_only;	# silently fail is this is author-only
	die "Cannot load $self->{dispatcher} for $self->{package}!\n:$@";
    }
    $self->{admin} ||= "$self->{package}\::$self->{dispatcher}"->new(
	_top => $self
    );
    my $obj = $self->{admin}->load($method);
    push @{$self->{extensions}}, $obj;
    return $obj;
}

sub load_extensions {
    my $self     = shift;
    my $basepath = (@_ ? shift : "$self->{prefix}/$self->{dir}");

    foreach my $rv ($self->find_extensions($basepath)) {
	my ($pathname, $extpkg) = @{$rv};
	$self->{pathnames}{$extpkg} = $pathname;

	eval { require $pathname ; 1 } or next;
	foreach my $sub (qw(AUTOLOAD call load)) {
	    *{"$extpkg\::$sub"}	= \&{$sub}
		unless defined &{"$extpkg\::$sub"};
	}
	my $extobj = $extpkg->can('new') ? $extpkg->new(_top => $self)
					 : bless({}, $extpkg);
	$extobj->{_top} = $self;
	push @{$self->{extensions}}, $extobj;
    }
}

# remove all modules and start anew - XXX this belongs elsewhere
sub purge_extensions {
    my $self = shift || $Def{package}->new;
    my ($file, $dir, $inc) = @{$self}{qw(file dir prefix)};

    foreach my $pathname ($self->find_files("$inc/$dir"), $file) {
	unlink $pathname or die "Cannot remove $pathname\n$!";
    }

    my @parts = ($inc, split('/', $dir));
    foreach my $i (reverse(0 .. $#parts)) {
	my $path = join('/', @parts[0..$i]);
	rmdir $path or last;
    }
}

# find files recursively - XXX rewrite using File::Find
sub find_extensions {
    my ($self, $basepath, $file, $path) = @_;
    $file = $basepath	    unless defined $file;
    $path = ''		    unless defined $path;
    $file = "$path/$file"   if length($path);

    if (-f $file) {
	next unless $file =~ m!^\Q$basepath\E/(.+)\.pm\Z!is;
	next if $1 eq $self->{dispatcher};
	my $extpkg = "$self->{package}\::$1";
	$extpkg =~ s!/!::!g;
        return [$file, $extpkg];
    }
    elsif (-d $file) {
        my @files = ();
        local *DIR;
        opendir(DIR, $file) or die "Can't opendir $file:\n$!";
        while (my $new_file = readdir(DIR)) {
            next if $new_file =~ /^(\.|\.\.)$/;
            push @files, $self->find_extensions($basepath, $new_file, $file);
        }
        return @files;
    }
    return ();
}

1;
