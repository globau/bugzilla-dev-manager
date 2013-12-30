package Bz::Workdir;
use Bz;
use Moo;

use Bz::Bug;
use Bz::Repo;
use CGI;
use Data::Dumper;
use File::Basename;
use File::Copy::Recursive 'dircopy';
use File::Find;
use File::Slurp;
use Safe;
use Test::Harness qw(&runtests);

has dir         => ( is => 'ro', required => 1 );
has path        => ( is => 'lazy' );
has summary     => ( is => 'lazy' );
has bug_id      => ( is => 'lazy' );
has bug         => ( is => 'lazy' );
has repo        => ( is => 'rw', lazy => 1, coerce => \&_coerce_repo, isa => \&_isa_repo, builder => 1 );
has repo_base   => ( is => 'lazy' );
has bzr_branch  => ( is => 'lazy' );
has db          => ( is => 'rw', lazy => 1, coerce => \&_coerce_db, builder => 1 );
has dbh         => ( is => 'lazy' );

use constant APPLY  => 0;
use constant REVERT => 1;

sub BUILD {
    my ($self, $args) = @_;
    return if $args->{ignore_error};
    die "invalid directory '" . $self->dir . "'\n"
        unless -e $self->path . '/localconfig';
}

sub _build_path {
    my ($self) = @_;
    return Bz->config->htdocs_path . '/' . $self->dir;
}

sub _build_summary {
    my ($self) = @_;
    return '' unless -d $self->path . '/data';
    if (-e $self->path . '/data/summary') {
        return read_file($self->path . '/data/summary');
    }
    my $summary = $self->bug ? $self->bug->summary : '';
    write_file($self->path . '/data/summary', $summary);
    return $summary;
}

sub _build_bug_id {
    my ($self) = @_;
    my $dir = $self->dir;

    return $dir unless $dir =~ /\D/;
    return $1 if $dir =~ /^(\d+)-/;
    return 0;
}

sub _build_bug {
    my ($self) = @_;
    return $self->bug_id
        ? Bz::Bug->new({ id => $self->bug_id })
        : undef;
}

sub _coerce_repo {
    my $repo = lc($_[0] || '');
    $repo =~ s#^repo[\\|/]##;
    $repo =~ s#-#/#g;
    return $repo;
}

sub _isa_repo {
    my ($repo) = @_;
    my $config = Bz->config;

    die "missing repo\n" if $repo eq '';
    my $found = 0;
    foreach my $try ("$repo", "bugzilla/$repo", "bmo/$repo") {
        if (-d $config->repo_path . "/$try") {
            $repo = $try;
            $found = 1;
            last;
        }
    }
    die "failed to find repo/$repo\n" unless $found;
    die "invalid repo '$repo'\n" unless -e $config->repo_path . "/$repo/checksetup.pl";
}

sub _build_repo {
    my ($self) = @_;
    my $filename = $self->path . '/data/repo-version';

    return read_file($filename) if -e $filename;

    my $repo = '';
    chdir($self->path);
    if (-d '.bzr') {
        my $bzr = `bzr info`;
        if ($bzr =~ m#bzr\.mozilla\.org/((bugzilla|bmo)/.+)#) {
            $repo = $1;
            $repo =~ s/(^\s+|\s+$)//g;
            $repo =~ s#/$##;
            $repo =~ s#/#-#;
        }
    }
    write_file($filename, $repo);
    return $repo;
}

sub _build_repo_base {
    my ($self) = @_;
    return (split('/', $self->repo))[0];
}

sub _build_bzr_branch {
    my ($self) = @_;

    my $bzr_branch = '';
    my $filename = $self->path . "/.bzr/branch/branch.conf";
    if (-e $filename) {
        my $conf = read_file($filename);
        ($bzr_branch) = $conf =~ /bound_location\s*=\s*(.+)\n/;
    }
    return $bzr_branch;
}

sub _coerce_db {
    my $db = lc($_[0] || '');
    $db =~ s/[\.-\/]/_/g;
    if ($db ne 'bugs' && $db !~ /^bugs_/) {
        $db = "bugs_$db";
    }
    return $db;
}

sub _build_db {
    my ($self) = @_;

    my $s = new Safe;
    $s->rdo($self->path . '/localconfig');
    die "Error reading localconfig $!" if $!;
    die "Error evaluating localconfig $@" if $@;
    return ${ $s->varglob('db_name') };
}

sub _build_dbh {
    my ($self) = @_;
    return Bz->mysql->dbh($self->db);
}

#

sub create_dir {
    my ($self) = @_;
    my $config = Bz->config;

    info("creating " . $self->dir . " directory");

    my $source_repo = Bz::Repo->new({ dir => $self->repo });
    my $dest_repo = Bz::Repo->new({ path => $self->path });

    dircopy($source_repo->path, $self->path)
        or die $!;
    foreach my $file (glob($self->path . '/*.patch')) {
        unlink $file;
    }
    find(sub {
        unlink($_) if /^\..+\.swp$/;
    }, $self->path);
    $dest_repo->fix(1);
    die $self->path . "/checksetup.pl missing\n" unless -e $self->path . "/checksetup.pl";
}

# XXX move localconfig creation and updating to dedicated class
sub create_default_localconfig {
    my ($self) = @_;
    return if -e $self->path . '/localconfig';
    info("creating " . $self->path . '/localconfig');
    my $content = <<'EOF';
$create_htaccess = 1;
$webservergroup = '';
$use_suexec = 0;
$db_driver = 'mysql';
$db_host = '';
$db_name = 'bugs';
$db_user = 'bugs';
$db_pass = '';
$db_port = 0;
$db_sock = '';
$db_check = 1;
$index_html = 0;
$cvsbin = '';
$interdiffbin = '';
$diffpath = '';
EOF
    write_file($self->path . '/localconfig', $content);
}

sub update_localconfig {
    my ($self) = @_;
    my $config = Bz->config;

    $config->localconfig->{db_name} = $self->db;

    my @file = read_file($self->path . '/localconfig');
    foreach my $line (@file) {
        next unless $line =~ /^\s*\$([\w_]+)\s*=\s*'([^']*)'/;
        my ($name, $value) = ($1, $2);
        if ($config->localconfig->$name
            && $config->localconfig->$name ne $value
        ) {
            message("setting $name to " . $config->localconfig->$name);
            $line = "\$$name = '" . $config->localconfig->$name . "';\n";
        }
    }
    write_file($self->path . '/localconfig', @file);
}

sub run_checksetup {
    my ($self, @args) = @_;
    info("running checksetup");
    chdir($self->path);
    system "./checksetup.pl @args";
}

sub fix {
    my ($self) = @_;
    $self->local_patches(APPLY);
    $self->fix_params();
    $self->fix_permissions();
    $self->delete_crud();
}

sub unfix {
    my ($self) = @_;
    $self->local_patches(REVERT);
    $self->revert_permissions();
    $self->delete_crud();
}

sub local_patches {
    my ($self, $revert) = @_;
    my $mode = $revert ? 'revert' : 'apply';

    my $dir = $self->dir;
    my $patches = [
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
                action  => sub { s/(\n(\s*)RewriteEngine On\n)/$1$2RewriteBase \/$dir\/\n/ },
            },
            revert   => {
                match   => sub { /\n\s*RewriteEngine On\n\s*RewriteBase/ },
                action  => sub { s/(\n\s*RewriteEngine On)\n\s*RewriteBase [^\n]+/$1/ },
            },
        },
    ];

    chdir($self->path);
    foreach my $patch (@$patches) {
        my $match  = $patch->{$mode}->{match};
        my $action = $patch->{$mode}->{action};

        if ($patch->{whole}) {
            $_ = read_file($patch->{file});
            next unless $match->();
            print(($revert ? 'reverting' : 'applying') . " patch " . $patch->{desc} . "\n");
            $action->();
            write_file($patch->{file}, $_);
        } else {
            my @file = read_file($patch->{file});
            foreach (@file) {
                next unless $match->();
                print(($revert ? 'reverting' : 'applying') . " patch " . $patch->{desc} . "\n");
                $action->();
            }
            write_file($patch->{file}, @file);
        }
    }
}

sub fix_params {
    my ($self) = @_;
    my $config = Bz->config;

    my $filename = $self->path . '/data/params';
    return unless -e $filename;

    my $s = new Safe;
    $s->rdo($filename);
    die "Error reading $filename: $!" if $!;
    die "Error evaluating $filename: $@" if $@;
    my %params = %{ $s->varglob('param') };
    my %orig_params = %params;

    foreach my $name ($config->params->_names) {
        $params{$name} = $config->params->$name;
    }

    if ($self->repo_base eq 'bmo') {
        foreach my $name ($config->params_bmo->_names) {
            $params{$name} = $config->params_bmo->$name;
        }
    }

    if ($self->dir eq 'mod_perl') {
        $params{urlbase}            = $config->modperl_url;
        $params{attachment_base}    = $config->modperl_attach_url;
        $params{cookiepath}         = "/";
        $params{cookiedomain}       = '';
    }

    foreach my $name (keys %params) {
        $params{$name} =~ s/\%dir\%/$self->dir/e;
    }

    my $id = $self->bug_id;

    $params{announcehtml} = sprintf(
        '<div style="' .
        'background: url(%sbkg_warning.png) repeat-y scroll left top #fff9db;' .
        'color: #666458;' .
        'padding: 5px 5px 5px 19px;' .
        '">%s (%s) %s</div>',
        $config->base_url,
        ($id
            ? qq#<a href="https://bugzilla.mozilla.org/show_bug.cgi?id=$id"><b>Bug $id</b></a>#
            : "<b>" . $self->dir . "</b>"
        ),
        $self->db,
        CGI::escapeHTML($self->summary),
    );

    foreach my $name (sort keys %params) {
        next if
            !exists $orig_params{$name}
            or $params{$name} eq $orig_params{$name};
        print "setting '$name' to '$params{$name}'\n";
    }

    local $Data::Dumper::Sortkeys = 1;
    write_file($filename, Data::Dumper->Dump([\%params], ['*param']));
}

sub fix_permissions {
    my ($self) = @_;

    chdir($self->path);
    my @spec = glob('*');
    push @spec, '.htaccess';
    push @spec, '.bzr' if -d ".bzr";

    my $user = getpwuid($>);
    system("chgrp -R --silent " . Bz->config->localconfig->webservergroup . " @spec");
    @spec = grep { $_ ne 'data' } @spec;
    sudo_on_output("chown -R $user @spec");
    sudo_on_output('find . -path ./data -prune -type d -exec chmod g+x {} \;');
    foreach my $file (`find . -type f -perm /111`) {
        chomp $file;
        next if $file =~ /\.(cgi|pl|swp)$/;
        next if $file =~ /^\.\/contrib\//;
        message("fixing permissions for $file");
        $file = '"' . $file . '"' if $file =~ / /;
        sudo_on_output("chmod -x $file");
    }
}

sub revert_permissions {
    my ($self) = @_;

    chdir($self->path);
    foreach my $line (`bzr diff`) {
        next unless $line =~ /modified file '([^']+)' \(properties changed: ([+-]x) to [+-]x\)/;
        my ($file, $perm) = ($1, $2);
        message("fixing properties for $file");
        $file = '"' . $file . '"' if $file =~ / /;
        sudo_on_output("chmod $perm $file");
    }
}

sub delete_crud {
    my ($self) = @_;

    my $path = $self->path;
    my @crud_dirs;
    find(
        sub {
            my $filename = $File::Find::name;
            return unless
                $filename =~ /\~\d+\~$/
                || basename($filename) =~ /^\._/
                || $filename =~ /\.orig$/
                || $filename =~ /\.moved$/
                || $filename =~ /\.rej$/;
            my $name = $filename;
            $name =~ s#^\Q$path\E/##;
            print "deleting $name\n";
            if (-d $filename) {
                push @crud_dirs, $filename;
            } else {
                unlink($filename);
            }
        },
        $path
    );
    foreach my $dir (@crud_dirs) {
        rmdir($dir);
    }
    if (-d "$path/data/deleteme") {
        print "deleting data/deleteme\n";
        system (qq#rm -rf "$path/data/deleteme"#);
        if (-d "$path/data/deleteme") {
            system (qq#sudo rm -rf "$path/data/deleteme"#);
        }
    }
}

sub check_db {
    my ($self) = @_;

    my $dbh = $self->dbh;
    my $count = $dbh->selectrow_array("SELECT count(*) FROM profiles WHERE disable_mail = 0");
    if ($count > 5) {
        warn($self->db . " has $count users with bugmail enabled\n");
    }
}

sub sudo_on_output {
    my ($command) = @_;
    my $output = `$command 2>&1`;
    if ($output) {
        message("escalating $command");
        system "sudo $command";
    }
}

sub added_files {
    my ($self) = @_;

    chdir($self->path);
    my $in_added = 0;
    my @added_files;
    foreach my $line (`bzr st`) {
        chomp $line;
        if ($line =~ /^  (.+)/) {
            my $file = $1;
            next if $file =~ /\@$/;
            push @added_files, $file if $in_added && !-d $file;
        } else {
            $in_added = $line eq 'added:';
        }
    }
    return @added_files;
}

sub run_tests {
    my ($self, $opts, @tests) = @_;

    chdir($self->path);
    $self->check_for_tabs();
    $self->check_for_unknown_files();
    $self->check_for_common_mistakes();
    $self->_run_tests($opts, @tests);
}

sub _run_tests {
    my ($self, $opts, @tests) = @_;

    my @test_files;
    if (@tests) {
        foreach my $number (@tests) {
            $number = sprintf("%03d", $number);
            push @test_files, glob("t/$number*.t");
        }
    } else {
        push @test_files, glob("t/*.t");
    }
    $Test::Harness::verbose = $opts->verbose if $opts;
    runtests(@test_files);
}

sub check_for_tabs {
    my ($self) = @_;

    my $root = $self->path,
    my @invalid;
    my @ignore = qw(
        js/change-columns.js
        t/002goodperl.t
    );
    find(sub {
            my $file = $File::Find::name;
            return if -d $file;
            return unless -T $file;
            return if $file =~ /^\Q$root\E\/(\.bzr|contrib|data|js\/yui\d?|docs)\//;
            return if $file =~ /\.patch$/;
            my $filename = $file;
            $filename =~ s/^\Q$root\E\///;
            return if grep { $_ eq $filename } @ignore;
            my $content = read_file($file);
            return unless $content =~ /\t/;
            push @invalid, $file;
        },
        $root
    );

    return unless @invalid;
    alert('The following files contain tabs:');
    foreach my $filename (@invalid) {
        $filename =~ s/^\Q$root\E\///;
        alert($filename);
    }
    die "\n";
}

sub check_for_unknown_files {
    my ($self) = @_;

    chdir($self->path);
    my @lines = `bzr st`;
    chomp(@lines);

    my @unknown;
    my $current;
    foreach my $line (@lines) {
        if ($line =~ /^([^:]+):/) {
            $current = $1;
        } elsif ($current eq 'unknown') {
            $line =~ s/^\s+//;
            next if $line =~ /\.patch$/;
            push @unknown, $line;
        }
    }
    return unless @unknown;

    alert('The following files are new but are missing from bzr:');
    my $root = quotemeta($self->path);
    foreach my $filename (@unknown) {
        $filename =~ s/^$root\///o;
        info($filename);
    }
}

sub check_for_common_mistakes {
    my ($self, $filename) = @_;

    chdir($self->path);
    my @lines;
    if ($filename) {
        @lines = read_file($filename);
    } else {
        @lines = `bzr diff`;
    }

    my %whitespace;
    my %xxx;
    my $hunk_file;
    foreach my $line (@lines) {
        next unless $line =~ /^\+/;
        if ($line =~ /^\+\+\+ (\S+)/) {
            $hunk_file = $1;
            next;
        }
        chomp($line);
        if ($line =~ /\s+$/) {
            my $ra = $whitespace{$hunk_file} ||= [];
            push @$ra, $line;
        }
        if ($line =~ /XXX/) {
            my $ra = $xxx{$hunk_file} ||= [];
            push @$ra, $line;
        }
    }
    if (scalar keys %whitespace) {
        alert("trailing whitespace added:");
        foreach my $file (sort keys %whitespace) {
            info($file);
            foreach my $line (@{ $whitespace{$file} }) {
                info("  $line");
            }
        }
    }
    if (scalar keys %xxx) {
        alert("line with XXX added:");
        foreach my $file (sort keys %xxx) {
            info($file);
            foreach my $line (@{ $xxx{$file} }) {
                info("   $line");
            }
        }
    }
}

1;
