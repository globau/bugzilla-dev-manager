package Bz::App::Command::fix;
use Bz::App -command;
use Bz;

sub abstract {
    return "XXX";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    if (my $workdir = eval { Bz->current_workdir }) {
        info("fixing instance " . $workdir->dir);
        $workdir->fix();
        return;
    }

    # XXX check for repo

    die "invalid working directory\n";
}

1;
