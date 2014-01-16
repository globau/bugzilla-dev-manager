package Bz::App::Command::new;
use parent 'Bz::App::Base';
use Bz;

use Bz::Bug;
use Bz::Repo;
use Bz::Workdir;

sub abstract {
    return "create a new instance";
}

sub usage_desc {
    return "bz <dir> [repo] [db]";
}

sub description {
    return <<EOF;
creates a new instance, using the provided name.

providing a bug_id as the <dir> is recommended.
EOF
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <dir>") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $config = Bz->config;
    my $mysql = Bz->mysql;

    # sanity check
    my $dir = shift @$args;
    die $config->htdocs_path . "/$dir exists\n"
        if -e $config->htdocs_path . "/$dir";

    # create workdir obj
    my $workdir = Bz::Workdir->new({ dir => $dir, ignore_error => 1 });
    my $bug = $workdir->bug;
    if ($bug) {
        info(sprintf("Bug %s: %s", $bug->id, $bug->summary));
    }

    # use bmo defaults if just 'bmo' is provided
    my ($repo, $db);
    if (scalar(@$args) == 1 && $args->[0] eq 'bmo') {
        ($repo, $db) = ($config->default_bmo_repo, $config->default_bmo_db);
    } else {
        ($repo, $db) = @$args;
    }

    $workdir->repo($self->_probe_repo($repo, $bug));
    $workdir->db($db || $self->_probe_db($bug));

    if (!$mysql->database_exists($workdir->db)) {
        exit unless confirm("the database '" . $workdir->db . "' does not exist, continue?");
    }

    info("creating $dir");
    info("using repo " . $workdir->repo);
    info("using database " . $workdir->db);

    Bz::Repo->new({ dir => $workdir->repo })->update();

    $workdir->create_dir();
    $workdir->run_checksetup('-t');
    $workdir->update_localconfig();
    $workdir->run_checksetup();
    $workdir->fix();
    $workdir->check_db();

    info("$dir created\n" . $workdir->summary);
    notify("$dir created");
}

sub _probe_repo {
    my ($self, $repo, $bug) = @_;
    my $config = Bz->config;

    if ($repo) {
        return $repo if -e $config->repo_path . "/$repo";
        foreach my $base (qw( bmo bugzilla )) {
            return "$base/$repo" if -e $config->repo_path . "/$base/$repo";
        }
        die "invalid repo: $repo\n";
    }

    if ($bug) {
        if ($bug->product eq 'Bugzilla') {
            $repo = $bug->target;
            $repo =~ s/^bugzilla //i;
            if ($repo eq '---' || $repo eq $config->bugzilla_trunk_milestone) {
                $repo = 'bugzilla/trunk';
            } else {
                $repo = "bugzilla/$repo";
            }
        } elsif ($bug->product eq 'bugzilla.mozilla.org') {
            $repo = $config->default_bmo_repo;
        } else {
            alert("unable to map " . $bug->product . " to a repo");
            $repo = $config->default_bmo_repo;
        }
    } else {
        $repo = $config->default_bmo_repo;
    }
    exit unless confirm("use repository '$repo'?");
    return $repo;
}

sub _probe_db {
    my ($self, $bug) = @_;
    my $config = Bz->config;

    my $db;
    if ($bug) {
        if ($bug->product eq 'Bugzilla') {
            $db = $bug->target;
            $db =~ s/^bugzilla //i;
            $db = 'trunk' if $db eq '---' || $db eq $config->bugzilla_trunk_milestone;
        } elsif ($bug->product eq 'bugzilla.mozilla.org') {
            $db = $config->default_bmo_db;
        } else {
            alert("unable to map " . $bug->product . " to a database");
            $db = $config->default_bmo_db;
        }
    } else {
        $db = $config->default_bmo_db;
    }
    $db = "bugs_$db" unless $db =~ /^bugs_/;
    exit unless confirm("use database '$db'?");
    return $db;
}

1;
