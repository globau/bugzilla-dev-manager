package Bz::Workdir;
use Bz;
use Moo;

extends 'Bz::Repo';

use Bz::Bug;
use Bz::LocalPatches;
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
has summary     => ( is => 'lazy' );
has bug_id      => ( is => 'lazy' );
has bug         => ( is => 'lazy' );
has repo        => ( is => 'rw', lazy => 1, coerce => \&_coerce_repo, isa => \&_isa_repo, builder => 1 );
has repo_base   => ( is => 'lazy' );
has db          => ( is => 'rw', lazy => 1, coerce => \&_coerce_db, builder => 1 );
has dbh         => ( is => 'lazy' );

use overload (
    '""' => sub { "instance " . $_[0]->dir }
);

sub BUILD {
    my ($self, $args) = @_;
    return if $args->{ignore_error};
    die "unvalid directory '" . $self->dir . "'\n"
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
    $repo =~ s#(^\s+|\s+$)##g;
    $repo =~ s#^repo[\\|/]##;
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
    my $repo = '';
    chdir($self->path);
    if (-d '.bzr') {
        my $bzr = `bzr info`;
        if ($bzr =~ m#bzr\.mozilla\.org/((bugzilla|bmo)/.+)#) {
            $repo = $1;
            $repo =~ s/(^\s+|\s+$)//g;
            $repo =~ s#/$##;
        }
    }
    return $repo;
}

sub _build_repo_base {
    my ($self) = @_;
    return (split('/', $self->repo))[0];
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
    $self->SUPER::fix();
    Bz::LocalPatches->apply($self);
    $self->fix_params();
    $self->fix_permissions();
}

sub unfix {
    my ($self) = @_;
    Bz::LocalPatches->revert($self);
    $self->revert_permissions();
    $self->delete_crud();
}

sub delete_crud {
    my ($self) = @_;
    $self->SUPER::delete_crud();

    my $filename = $self->path . '/data/repo-version';
    return unless -e $filename;

    message("deleting data/repo-version");
    unlink($filename);
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
        message("setting '$name' to '$params{$name}'");
    }

    local $Data::Dumper::Sortkeys = 1;
    write_file($filename, Data::Dumper->Dump([\%params], ['*param']));
}

sub fix_permissions {
    my ($self) = @_;
    chdir($self->path);

    $self->SUPER::fix_permissions();
    my @spec = glob('*');
    push @spec, '.htaccess';
    push @spec, '.bzr' if -d ".bzr";

    my $user = getpwuid($>);
    system("chgrp -R --silent " . Bz->config->localconfig->webservergroup . " @spec");
    @spec = grep { $_ ne 'data' } @spec;
    sudo_on_output("chown -R $user @spec");
    sudo_on_output('find . -path ./data -prune -type d -exec chmod g+x {} \;');
}

sub check_db {
    my ($self) = @_;

    my $dbh = $self->dbh;
    my $count = $dbh->selectrow_array("SELECT count(*) FROM profiles WHERE disable_mail = 0");
    if ($count > 5) {
        warn($self->db . " has $count users with bugmail enabled\n");
    }
}

sub test {
    my ($self, $opt, $args) = @_;

    $self->SUPER::test();
    $self->run_tests($opt, $args);
}

sub run_tests {
    my ($self, $opt, $args) = @_;

    chdir($self->path);
    my @test_files;
    if ($args && @$args) {
        foreach my $number (@$args) {
            $number = sprintf("%03d", $number);
            push @test_files, glob("t/$number*.t");
        }
    } else {
        push @test_files, glob("t/*.t");
    }
    $Test::Harness::verbose = $opt->verbose if $opt;
    runtests(@test_files);
}

1;
