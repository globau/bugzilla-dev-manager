package Bz::LocalPatches;
use Bz;

use File::Slurp;

use constant PATCHES => (
    {
        desc    => '__DIE__ handler',
        file    => 'Bugzilla.pm',
        apply   => {
            match   => sub { /^# ?\$::SIG{__DIE__} = i_am_cgi/ },
            action  => sub { s/^#\s*// },
        },
        revert  => {
            match   => sub { /^\$::SIG{__DIE__} = i_am_cgi/ },
            action  => sub { s/^/#/ },
        },
    },
    {
        desc    => 't/012 warnings to errors',
        file    => 't/012throwables.t',
        apply   => {
            match   => sub { /^\s+ok\(1, "--WARNING \$file has " \. scalar\(\@errors\)/ },
            action  => sub { s/ok\(1,/ok\(0,/ },
        },
        revert  => {
            match   => sub { /^\s+ok\(0, "--WARNING \$file has " \. scalar\(\@errors\)/ },
            action  => sub { s/ok\(0,/ok\(1,/ },
        },
    },
    {
        desc    => 'mod_perl sizelimit',
        file    => 'mod_perl.pl',
        apply   => {
            match   => sub { /^\s+Apache2::SizeLimit->set_max_unshared_size\(250_000\)/ },
            action  => sub { s/\(250_000\)/(1_000_000)/ },
        },
        revert  => {
            match   => sub { /^\s+Apache2::SizeLimit->set_max_unshared_size\(1_000_000\)/ },
            action  => sub { s/\(1_000_000\)/(250_000)/ },
        },
    },
    {
        desc    => '.htaccess',
        file    => '.htaccess',
        whole   => 1,
        apply   => {
            match   => sub { /\n\s*RewriteEngine On\n(?!\s*RewriteBase)/ },
            action  => sub { my $dir = $_[0]->dir; s/(\n(\s*)RewriteEngine On\n)/$1$2RewriteBase \/$dir\/\n/ },
        },
        revert   => {
            match   => sub { /\n\s*RewriteEngine On\n\s*RewriteBase/ },
            action  => sub { s/(\n\s*RewriteEngine On)\n\s*RewriteBase [^\n]+/$1/ },
        },
    },
);

sub apply {
    my ($class, $workdir) = @_;
    $class->_patch($workdir, 'apply');
}

sub revert {
    my ($class, $workdir) = @_;
    $class->_patch($workdir, 'revert');
}

sub _patch {
    my ($class, $workdir, $mode) = @_;

    chdir($workdir->path);
    foreach my $patch (PATCHES) {
        my $match  = $patch->{$mode}->{match};
        my $action = $patch->{$mode}->{action};

        if ($patch->{whole}) {
            $_ = read_file($patch->{file});
            next unless $match->($workdir);
            print(($mode eq 'revert' ? 'reverting' : 'applying') . " patch " . $patch->{desc} . "\n");
            $action->($workdir);
            write_file($patch->{file}, $_);
        } else {
            my @file = read_file($patch->{file});
            foreach (@file) {
                next unless $match->($workdir);
                print(($mode eq 'revert' ? 'reverting' : 'applying') . " patch " . $patch->{desc} . "\n");
                $action->($workdir);
            }
            write_file($patch->{file}, @file);
        }
    }
}

1;
