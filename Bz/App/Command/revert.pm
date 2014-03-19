package Bz::App::Command::revert;
use parent 'Bz::App::Base';
use Bz;

use File::Path qw(remove_tree);

sub abstract {
    return "reverts all changes made to an instance";
}

sub execute {
    my ($self, $opt, $args) = @_;

    info("reverting all local changes and commits");
    my $workdir = Bz->current_workdir;
    $workdir->unfix();
    $workdir->git(
        'reset',
        'origin/' . $workdir->branch,
        '--hard',
    );
    $workdir->git(qw(clean -f -d));
    $workdir->git('pull');
    $workdir->fix();
}

1;
