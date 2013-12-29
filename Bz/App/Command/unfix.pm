package Bz::App::Command::unfix;
use Bz::App -command;
use Bz;

sub abstract {
    return "reverts changes made by fix";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $workdir = Bz->current_workdir;
    info("unfixing instance " . $workdir->dir);
    $workdir->unfix();
}

1;
