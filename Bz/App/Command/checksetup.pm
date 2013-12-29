package Bz::App::Command::checksetup;
use Bz::App -command;
use Bz;

sub command_names {
    qw(
        checksetup
        cs
    );
}

sub abstract {
    return "runs checkseutp.pl";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    info("running checksetup.pl");
    chdir($workdir->path);
    system "./checksetup.pl " . join(' ', @$args);
}

1;
