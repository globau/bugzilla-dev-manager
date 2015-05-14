package Bz::LocalPatches;
use Bz;

use File::Slurp;

my %filter_defaults = (
    modperl     => 0,
    repo        => '',      # bmo || bugzilla
    branch_min  => '0',
    branch_max  => '999',
);

use constant PATCHES => (
    {
        desc    => '__DIE__ handler (old upstream)',
        file    => 'Bugzilla.pm',
        filter  => {
            repo        => 'bugzilla',
            branch_max  => '4.2',
        },
        apply   => {
            match   => sub { /^# ?\$::SIG{__DIE__} = i_am_cgi/ },
            action  => sub { s/^#\s*// },
        },
        revert  => {
            match   => sub { /^\$::SIG{__DIE__} = i_am_cgi/ },
            action  => sub { s/^/# / },
        },
    },
    {
        desc    => '__DIE__ handler',
        file    => 'Bugzilla.pm',
        filter  => [
            {
                repo        => 'bugzilla',
                branch_min  => '4.4',
            },
            {
                repo        => 'bmo',
            },
        ],
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
        desc    => 't/012 warnings skip password* errors',
        file    => 't/012throwables.t',
        apply   => {
            match   => sub { /^\s+DefinedIn\(\$errtype, \$errtag, \$lang\);$/ },
            action  => sub { s/^([^;]+);$/$1 unless \$errtype eq 'user' and \$errtag =~ \/^password\/;/ },
        },
        revert  => {
            match   => sub { /^\s+DefinedIn\(\$errtype, \$errtag, \$lang\) unless/ },
            action  => sub { s/^(\s+).+$/$1DefinedIn(\$errtype, \$errtag, \$lang);/ },
        },
    },
    {
        desc    => 'mod_perl sizelimit',
        file    => 'mod_perl.pl',
        filter  => {
            modperl     => 1,
        },
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
        desc    => '.htaccess rewritebase',
        file    => '.htaccess',
        whole   => 1,
        filter  => {
            modperl     => 0,
        },
        apply   => {
            match   => sub { /\bRewriteEngine On\b/ && !/\bRewriteBase\b/ },
            action  => sub { my $dir = $_[0]->dir; s/(\n(\s*)RewriteEngine On\n)/$1$2RewriteBase \/$dir\/\n/ },
        },
        revert   => {
            match   => sub { /\n\s*RewriteEngine On\n\s*RewriteBase/ },
            action  => sub { s/(\n\s*RewriteEngine On)\n\s*RewriteBase [^\n]+/$1/ },
        },
    },
    {
        desc    => 'BugzillaTitle',
        file    => 'extensions/BMO/template/en/default/hook/global/variables-end.none.tmpl',
        apply   => {
            match   => sub { /Bugzilla\@Mozilla/ },
            action  => sub { s/Bugzilla\@Mozilla/Bugzilla\@Development/ },
        },
        revert  => {
            match   => sub { /Bugzilla\@Development/ },
            action  => sub { s/Bugzilla\@Development/Bugzilla\@Mozilla/ },
        },
    },
    {
        desc    => 'asset concatenation',
        file    => 'Bugzilla/Constants.pm',
        apply   => {
            match   => sub { /CONCATENATE_ASSETS => 1;/ },
            action  => sub { s/CONCATENATE_ASSETS => 1/CONCATENATE_ASSETS => 0/ },
        },
        revert  => {
            match   => sub { /use constant CONCATENATE_ASSETS => 0;/ },
            action  => sub { s/CONCATENATE_ASSETS => 0/CONCATENATE_ASSETS => 1/ },
        },
    },
    {
        desc    => 'fix safesys',   # see bug 1116118
        file    => 't/003safesys.t',
        whole   => 1,
        apply   => {
            match   => sub { !/File::Slurp/ },
            action  => sub {
                my $line = q#use File::Slurp; if (scalar(read_file $file) !~ /\b(system|exec)\b/) { ok(1,"$file does not call system or exec"); next }#;
                s/(my \$command)/$line $1/;
            },
        },
        revert  => {
            match   => sub { /File::Slurp.+my \$command/ },
            action  => sub {
                s/(\n\s+)use File::Slurp.+?(my \$command)/$1$2/;
            },
        },
    },
    {
        desc    => 'disable sentry',
        file    => 'Bugzilla/Sentry.pm',
        apply   => {
            match   => sub { /^\s+install_sentry_handler\(\);$/ },
            action  => sub { s/^/#/ },
        },
        revert  => {
            match   => sub { /^#\s+install_sentry_handler\(\);$/ },
            action  => sub { s/^#// },
        },
    },
    {
        desc    => 'inactive reviewers',
        file    => 'extensions/Review/Extension.pm',
        apply   => {
            match   => sub { /MAX_REVIEWER_LAST_SEEN_DAYS_AGO => 60;/ },
            action  => sub { s/(MAX_REVIEWER_LAST_SEEN_DAYS_AGO) => 60/$1 => 0/ },
        },
        revert  => {
            match   => sub { /MAX_REVIEWER_LAST_SEEN_DAYS_AGO => 0;/ },
            action  => sub { s/(MAX_REVIEWER_LAST_SEEN_DAYS_AGO) => 0/$1 => 60/ },
        },
    },
    {
        # use ::XXX($object) or ::XXX(var_name => $object)
        # globally scoped, will output to STDERR using Data::Dumper
        desc    => '::XXX debugging',
        file    => 'Bugzilla.pm',
        whole   => 1,
        apply   => {
            match   => sub { !/sub main::XXX/ },
            action  => sub {
                my $sub = <<'EOF';
sub main::XXX {
    require Data::Dumper;
    my $d;
    if (scalar(@_) == 1) {
        my ($value) = @_;
        if (!ref($value)) {
            $value =~ s/\n+$//;
            print STDERR $value, "\n";
            return;
        }
        $d = Data::Dumper->new([ $value ]);
        $d->Terse(1);
    } else {
        my ($name, $value) = @_;
        $d = Data::Dumper->new([ $value ], [ $name ]);
    }
    $d->Sortkeys(1)->Quotekeys(0);
    print STDERR $d->Dump();
}
EOF
                $sub =~ s/\n\s+/ /g;
                $sub =~ s/\n\}/ }/g;
                s/\n1;\n/\n${sub}1;\n/;
            },
        },
        revert  => {
            match   => sub { /sub main::XXX/ },
            action  => sub {
                s/\nsub main::XXX[^\n]+//;
            },
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
    PATCH: foreach my $patch (PATCHES) {
        next unless -e $patch->{file};

        my $filters = $patch->{filter} || [ {} ];
        $filters = [ $filters ] unless ref($filters) eq 'ARRAY';
        foreach my $filter (@$filters) {
            foreach my $field (keys %filter_defaults) {
                $filter->{$field} //= $filter_defaults{$field};
            }
            $filter->{match} = 1;

            if ($filter->{modperl}) {
                if (!$workdir->is_mod_perl) {
                    $filter->{match} = 0;
                    next;
                }
            }

            if ($workdir->is_upstream) {
                my $branch = $workdir->branch eq 'master' ? '999' : $workdir->branch;
                if (vers_cmp($branch, $filter->{branch_min}) < 0) {
                    $filter->{match} = 0;
                    next;
                }
                if (vers_cmp($branch, $filter->{branch_max}) > 0) {
                    $filter->{match} = 0;
                    next;
                }
            }

            if ($filter->{repo}) {
                if ($filter->{repo} eq 'bmo' && $workdir->is_upstream) {
                    $filter->{match} = 0;
                    next;
                }
                if ($filter->{repo} eq 'bugzilla' && !$workdir->is_upstream) {
                    $filter->{match} = 0;
                    next;
                }
            }
        }
        next unless grep { $_->{match} } @$filters;

        my $match  = $patch->{$mode}->{match};
        my $action = $patch->{$mode}->{action};

        if ($patch->{whole}) {
            $_ = read_file($patch->{file});
            next unless $match->($workdir);
            message(($mode eq 'revert' ? 'reverting' : 'applying') . " patch " . $patch->{desc});
            $action->($workdir);
            write_file($patch->{file}, $_);
        } else {
            my @file = read_file($patch->{file});
            foreach (@file) {
                next unless $match->($workdir);
                message(($mode eq 'revert' ? 'reverting' : 'applying') . " patch " . $patch->{desc});
                $action->($workdir);
            }
            write_file($patch->{file}, @file);
        }
    }
}

1;
