package Bz::App::Command::checksetup;
use parent 'Bz::App::Base';
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
executes checksetup.pl for the current working directory (from any location
with in).
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
