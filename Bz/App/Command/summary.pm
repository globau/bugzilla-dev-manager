package Bz::App::Command::summary;
use parent 'Bz::App::Base';
use Bz;

use Cwd 'abs_path';
use File::Basename;

sub abstract {
    return "shows a one line summary of the current instance";
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $path = abs_path('.');
    return if $path eq Bz->config->htdocs_path || $path eq Bz->config->repo_path;

    if (my $workdir = eval { Bz->current_workdir }) {
        info(
            $workdir->bug_id
                ? "[Bug " . $workdir->bug->id . "] " . $workdir->summary
                : $workdir->dir
        );

    } elsif (my $repo = eval { Bz->current_repo }) {
        info('repo/' . $repo->dir);

    } elsif (substr($path, 0, length(Bz->config->repo_path)) eq Bz->config->repo_path) {
        info('repo/' . basename($path));

    } else {
        Bz->current;
    }
}

1;
