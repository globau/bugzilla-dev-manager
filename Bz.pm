package Bz;
use strict;
use warnings;
use autodie;

use Bz::Util;
use Cwd 'abs_path';
use Data::Dumper;
use File::Spec;

sub init {
    $SIG{__DIE__} = sub {
        my $message = "@_";
        # urgh
        $message =~ s/^(?:isa check|coercion) for "[^"]+" failed: //;
        $message =~ s/\n+$//;
        die Bz::Util::die_coloured($message) . "\n";
    };
    $SIG{__WARN__} = sub {
        print Bz::Util::warn_coloured(@_);
    };
    $Data::Dumper::Sortkeys = 1;
    binmode(STDOUT, ':utf8');
    binmode(STDERR, ':utf8');
}

BEGIN {
    init();
}

sub import {
    # enable strict, warnings, and autodie
    strict->import();
    warnings->import(FATAL => 'all');
    autodie->import();

    # re-export Bz::Util exports, and Data::Dumper
    my $dest_pkg = caller();
    eval "package $dest_pkg; Bz::Util->import(); Data::Dumper->import()";
}

my $_config;
sub config {
    require Bz::Config;
    return $_config ||= Bz::Config->new();
}

my $_bugzilla;
sub bugzilla {
    require Bz::Bugzilla;
    return $_bugzilla ||= Bz::Bugzilla->new();
}

my $_mysql;
sub mysql {
    require Bz::MySql;
    return $_mysql ||= Bz::MySql->new();
}

my $_boiler_plate;
sub boiler_plate {
    require Bz::BoilerPlate;
    return $_boiler_plate ||= Bz::BoilerPlate->new();
}

#

sub current_workdir {
    require Bz::Workdir;
    my $path = abs_path('.')
        or die "failed to find current working directory\n";
    $path .= '/';
    die "invalid working directory\n"
        unless $path =~ m#/htdocs/([^/]+)/#
        && -e "$path/Bugzilla.pm";
    return Bz::Workdir->new({ dir => $1 });
}

sub current_repo {
    require Bz::Repo;
    my $path = abs_path('.')
        or die "failed to find current working directory\n";
    while (!-d "$path/.bzr" && !-d "$path/.git") {
        my @dirs = File::Spec->splitdir($path);
        pop @dirs;
        $path = File::Spec->catdir(@dirs);
        die "invalid working directory\n" if $path eq '/';
    }
    die "invalid working directory\n"
        unless -e "$path/Bugzilla.pm";
    return Bz::Repo->new({ path => $path });
}

sub current {
    my ($class) = @_;
    my $current = eval { $class->current_workdir() };
    return $current if $current;
    $current = eval { $class->current_repo() };
    return $current if $current;
    die "invalid working directory\n";
}

my $_workdirs;
sub workdirs {
    require Bz::Workdir;
    chdir(Bz->config->htdocs_path);
    return $_workdirs ||= [
        map { Bz::Workdir->new({ dir => $_ }) }
        grep { !-l $_ && -d $_ }
        glob('*')
    ];
}

sub preload_bugs {
    my ($class, $workdirs) = @_;
    my @bug_ids = map { $_->bug_id } grep { $_->bug_id } @$workdirs;
    Bz->bugzilla->bugs(\@bug_ids);
}

#

sub workdir {
    my ($class, $dir) = @_;
    require Bz::Workdir;
    return Bz::Workdir->new({ dir => $dir });
}

sub bug {
    my ($class, $bug_id) = @_;
    require Bz::Bug;
    return Bz::Bug->new({ id => $bug_id });
}

1;
