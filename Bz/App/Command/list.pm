package Bz::App::Command::list;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "lists all instances";
}

sub execute {
    my ($self, $opt, $args) = @_;

    foreach my $workdir (@{ Bz->config->workdirs }) {
        printf "%s: %s\n", $workdir->dir, $workdir->summary;
    }
}

1;
