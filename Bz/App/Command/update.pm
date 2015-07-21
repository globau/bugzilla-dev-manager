package Bz::App::Command::update;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    up
);

sub abstract {
    return "performs 'git pull --rebase' without local patches applied";
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current;
    $current->unfix();
    $current->git('stash');
    $current->git('pull', '--rebase');
    $current->git('stash', 'pop');
    $current->fix();
}

1;
