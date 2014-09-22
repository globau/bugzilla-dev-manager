package Bz::App::Command::status;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    st
);

sub abstract {
    return "same as |git status|, but excludes dev-manager specific changes";
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current;
    disable_messages();
    $current->unfix() if $current->is_workdir;
    enable_messages();

    $current->git('status');

    disable_messages();
    $current->fix() if $current->is_workdir;
    enable_messages();
}

1;
