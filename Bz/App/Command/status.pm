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
    silent {
        $current->unfix() if $current->is_workdir;
    };

    $current->git('status');

    silent {
        $current->fix() if $current->is_workdir;
    };
}

1;
