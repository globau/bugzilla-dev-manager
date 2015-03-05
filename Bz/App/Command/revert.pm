package Bz::App::Command::revert;
use parent 'Bz::App::Base';
use Bz;

use File::Path qw(remove_tree);

sub abstract {
    return "reverts changes made to an instance.";
}

sub usage_desc {
    return "bz revert [--all]";
}

sub opt_spec {
    return (
        [ "all|a|d",  "revert all changes (removes untracked files)" ],
    );
}

sub description {
    return <<EOF;
be default all changes made to tracked files will be reverted.
passing in --all or -a will additionally delete untracked files.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    info("reverting" . ($opt->all ? " all" : "") . " local changes and commits");
    my $current = Bz->current;
    $current->unfix() if $current->is_workdir;
    $current->git(
        'reset',
        'origin/' . $current->branch,
        '--hard',
    );
    if ($opt->all) {
        $current->git(qw(clean --force -d));
    } else {
        $current->git(qw(status --short));
    }
    $current->git('pull');
    $current->fix() if $current->is_workdir;
}

1;
