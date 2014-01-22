package Bz::App::Command::path;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "prints the path to the specified instance/repo";
}

sub usage_desc {
    return "bz path [--repo] [dir]";
}

sub opt_spec {
    return (
        [ "repo|r", "search for a repo" ],
    );
}

sub description {
    return <<EOF;
prints the full path to the specified instance (or repo if --repo is specified).

this is intended for use from shell aliases:
  cd `bz path "\$@"`
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $path;

    if ($opt->repo) {
        if (@$args) {
            my $repo = $args->[0];
            my $repo_path = Bz->config->repo_path;

            # repo path, eg "bmo/4.2"
            if (-e "$repo_path/$repo") {
                $path = "$repo_path/$repo";

            } else {
                # repo dir, eg "trunk"
                foreach my $base (qw( bmo bugzilla )) {
                    if (-d "$repo_path/$base/$repo") {
                        $path = "$repo_path/$base/$repo";
                        last;
                    }
                }
            }
        } elsif (my $repo = eval { Bz->current_repo() }) {
            # root path of current repo
            $path = $repo->path;
        }
        $path ||= Bz->config->repo_path;

    } else {
        if (@$args) {
            # workdir substring match
            foreach my $workdir (@{ Bz->workdirs() }) {
                my $match = 1;
                foreach my $word (@$args) {
                    if ($workdir->dir !~ /\Q$word\E/i && $workdir->summary !~ /\Q$word\E/i) {
                        $match = 0;
                        last;
                    }
                }
                if ($match) {
                    $path = $workdir->path;
                    last;
                }
            }
        } elsif (my $workdir = eval { Bz->current_workdir() }) {
            # root path of current instance
            $path = $workdir->path;
        }
        $path ||= Bz->config->htdocs_path;
    }

    print $path, "\n";
}

1;
