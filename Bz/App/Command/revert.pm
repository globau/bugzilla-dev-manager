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
    my $current = Bz->current;
    $current->unfix() if $current->is_workdir;
    $current->git(
        'reset',
        'origin/' . $current->branch,
        '--hard',
    );
    $current->git(qw(clean -f -d));
    $current->git('pull');
    $current->fix() if $current->is_workdir;
}

1;
