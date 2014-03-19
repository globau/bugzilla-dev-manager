package Bz::App::Command::pending;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "shows files committed but not pushed";
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $repo = Bz->current_repo;
    Bz->current_repo->git(
        'diff',
        'origin/' . $repo->branch,
        $repo->branch,
        '--name-status',
    );
}

1;
