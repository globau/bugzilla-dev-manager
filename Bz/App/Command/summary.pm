package Bz::App::Command::summary;
use parent 'Bz::App::Base';
use Bz;

use Cwd 'abs_path';

sub abstract {
    return "shows a one line summary of the current instance";
}

sub execute {
    my ($self, $opt, $args) = @_;
    return if abs_path('.') eq Bz->config->htdocs_path;
    my $workdir = Bz->current_workdir;
    info(
        $workdir->bug_id
            ? "[Bug " . $workdir->bug->id . "] " . $workdir->summary
            : $workdir->dir
    );
}

1;
