package Bz::App::Command::list;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "lists all instances";
}

sub execute {
    my ($self, $opt, $args) = @_;

    foreach my $workdir (@{ Bz->config->workdirs }) {
        message(sprintf("%s: %s", $workdir->dir, $workdir->summary));
    }
}

1;
