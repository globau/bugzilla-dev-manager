package Bz;
use strict;
use warnings;
use autodie;

use Bz::Terminal;
use Cwd 'abs_path';

BEGIN {
    $SIG{__DIE__} = sub {
        my $message = "@_";
        # urgh
        $message =~ s/^(?:isa check|coercion) for "[^"]+" failed: //;
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

    # re-export Bz::Terminal exports
    my $dest_pkg = caller();
    eval "package $dest_pkg; Bz::Terminal->import();";
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

#

sub current_workdir {
    require Bz::Workdir;
    my $dir = abs_path('.') . '/';
    return unless $dir =~ m#/htdocs/([^/]+)/#;
    $dir = $1;
    return Bz::Workdir->new({ dir => $dir });
}

1;
