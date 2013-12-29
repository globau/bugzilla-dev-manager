package Bz;
use strict;
use warnings;
use autodie;

use Bz::Terminal;
use Cwd 'abs_path';
use Data::Dumper;

BEGIN {
    $Data::Dumper::Sortkeys = 1;
    $SIG{__DIE__} = sub {
        my $message = "@_";
        # urgh
        $message =~ s/^(?:isa check|coercion) for "[^"]+" failed: //;
        $message =~ s/\n+$//;
        die Bz::Terminal::die_coloured($message) . "\n";
    };
    $SIG{__WARN__} = sub {
        print Bz::Terminal::warn_coloured(@_);
    };
}

sub import {
    # enable strict, warnings, and autodie
    strict->import();
    warnings->import(FATAL => 'all');
    autodie->import();

    # re-export Bz::Terminal exports, and Data::Dumper
    my $dest_pkg = caller();
    eval "package $dest_pkg; Bz::Terminal->import(); Data::Dumper->import()";
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

my $_util;
sub util {
    require Bz::Util;
    return $_util ||= Bz::Util->new();
}

#

sub current_workdir {
    require Bz::Workdir;
    my $dir = abs_path('.') . '/';
    die "invalid working directory\n"
        unless $dir =~ m#/htdocs/([^/]+)/#;
    $dir = $1;
    return Bz::Workdir->new({ dir => $dir });
}

1;
