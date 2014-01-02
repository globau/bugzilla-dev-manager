package Bz::Config;
use Bz;
use Moo;

use Bz::Workdir;
use Config::General;

# bz.conf

has prefs_path  => ( is => 'lazy' );
has _config     => ( is => 'lazy' );

sub _build_prefs_path {
    my $path = "~/.bz-dev";
    $path =~ s{^~([^/]*)}{$1 ? (getpwnam($1))[7] : (getpwuid($<))[7]}e;
    mkdir($path) unless -d $path;
    return $path;
}

sub _build__config {
    my ($self) = @_;
    my %config = Config::General->new(
        -ConfigFile         => $self->prefs_path . "/bz.conf",
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

# globals

has workdirs => ( is => 'lazy' );

sub _build_workdirs {
    my ($self) = @_;
    chdir($self->htdocs_path);
    return [
        grep { $_->summary }
        map { Bz::Workdir->new({ dir => $_ }) }
        grep { !-l $_ && -d $_ }
        glob('*')
    ];
}

1;

package Bz::Config::Section;
use strict;
use warnings;

sub new {
    my ($class, $args) = @_;
    bless($args, $class);
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
    return exists $self->{$name} ? $self->{$name} : undef;
}

1;
