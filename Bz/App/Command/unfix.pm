package Bz::App::Command::unfix;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "reverts changes made by fix";
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $workdir = Bz->current_workdir;
    info("unfixing instance " . $workdir->dir);
    $workdir->unfix();
}

1;
