package Bz;
use strict;
use warnings;
use autodie;

use Bz::Util;
use Cwd 'abs_path';
use Data::Dumper;
use File::Spec;

BEGIN {
    $Data::Dumper::Sortkeys = 1;
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
    my $path = abs_path('.') . '/';
    die "invalid working directory\n"
        unless $path =~ m#/htdocs/([^/]+)/#;
    return Bz::Workdir->new({ dir => $1 });
}

sub current_repo {
    require Bz::Repo;
    my $path = abs_path('.');
    while (!-d "$path/.bzr") {
        my @dirs = File::Spec->splitdir($path);
        pop @dirs;
        $path = File::Spec->catdir(@dirs);
        die "invalid working directory\n" if $path eq '/';
    }
    return Bz::Repo->new({ path => $path });
}

1;
