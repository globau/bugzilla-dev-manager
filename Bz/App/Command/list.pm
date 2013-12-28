package Bz::App::Command::list;
use Bz::App -command;
use Bz;

sub execute {
    my ($self, $opt, $args) = @_;

    foreach my $workdir (@{ Bz->config->workdirs }) {
        printf "%s: %s\n", $workdir->dir, $workdir->summary;
    }
}

sub abstract {
    return "lists all instances";
}

1;
