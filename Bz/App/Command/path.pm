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
    my $fallback = 0;

    if ($opt->repo) {
        if (@$args) {
            my $repo = $args->[0];
            my $repo_path = Bz->config->repo_path;

            # repo path, eg "bmo/4.2"
            if (-e "$repo_path/$repo") {
                $path = "$repo_path/$repo";
            }

            # repo dir, eg "trunk"
            unless ($path) {
                foreach my $base (qw( bmo bugzilla )) {
                    if (-d "$repo_path/$base/$repo") {
                        $path = "$repo_path/$base/$repo";
                        last;
                    }
                }
            }

            # repo dir prefix, eg "dev" --> "dev*" --> "development"
            unless ($path) {
                foreach my $base (qw( bmo bugzilla )) {
                    my @dirs = grep { -d $_ && !/\./ } glob("$repo_path/$base/$repo*");
                    if (scalar @dirs == 1) {
                        $path = $dirs[0];
                        last;
                    }
                }
            }

            $path
              || warning("failed to find repo: $repo");
        } elsif (my $repo = eval { Bz->current_repo() }) {
            # root path of current repo
            $path = $repo->path;
        }
        if (!$path) {
            $fallback = 1;
            $path = Bz->config->repo_path;
        }

    } else {
        if (@$args) {
            # dir match
            if (scalar(@$args) == 1) {
                my $dir = $args->[0];
                foreach my $workdir (@{ Bz->workdirs() }) {
                    if ($workdir->dir eq $dir) {
                        $path = $workdir->path;
                        last;
                    }
                }
                if (!$path) {
                    $dir =~ s/[\- \/]/_/g;
                    foreach my $workdir (@{ Bz->workdirs() }) {
                        if ($workdir->dir eq $dir) {
                            $path = $workdir->path;
                            last;
                        }
                    }
                }
            }
            if (!$path) {
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
            }
            alert("no instances matching '" . join(' ', @$args) . "'")
                unless $path;
        } elsif (my $workdir = eval { Bz->current_workdir() }) {
            # root path of current instance
            $path = $workdir->path;
        }
        if (!$path) {
            $fallback = 1;
            $path = Bz->config->htdocs_path;
        }
    }

    print $path, "\n";
    exit(1) if $fallback;
}

1;
