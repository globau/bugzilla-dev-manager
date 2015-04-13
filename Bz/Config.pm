package Bz::Config;
use Bz;
use Moo;

use Bz::Workdir;
use Config::General;

use constant CONF_FILENAME => '/etc/bz-dev.conf';

has user_path  => ( is => 'lazy' );
has _config    => ( is => 'lazy' );

sub _build_user_path {
    my $path = "~/.bz-dev";
    $path =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}e;
    mkdir($path) unless -d $path;
    return $path;
}

sub _build__config {
    my ($self) = @_;
    die "failed to find " . CONF_FILENAME . "\n"
        unless -e CONF_FILENAME;
    my %config = Config::General->new(
        -ConfigFile         => CONF_FILENAME,
        -LowerCaseNames     => 1,
        -InterPolateVars    => 1,
    )->getall();
    return \%config;
}

sub _names {
    my ($self) = @_;
    return sort keys %{ $self->_config };
}

sub AUTOLOAD {
    my ($self) = @_;
    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    my $config = $self->_config;
    return unless exists $config->{$name};
    if (ref($config->{$name})) {
        return $self->{$name} = Bz::Config::Section->new($config->{$name});
    }
    return $config->{$name};
}

1;

package Bz::Config::Section;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    bless($args, $class);
}

sub get {
    my ($self, $name) = @_;
    return exists $self->{$name} ? $self->{$name} : undef;
}

sub _names {
    my ($self) = @_;
    return sort keys %$self;
}

sub AUTOLOAD {
    my ($self) = @_;
    our $AUTOLOAD;
    my $name = $AUTOLOAD;
    $name =~ s/.*:://;
    return $self->get($name);
}

1;
