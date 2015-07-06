package Bz::App::Command::checksetup;
use parent 'Bz::App::Base';
use Bz;

use IPC::System::Simple qw(runx EXIT_ANY);

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

    # default to not precompiling templates
    # use --template to force precompilation
    if (!@$args) {
        push @$args, '--no-templates';
    } else {
        @$args = grep { $_ ne '--templates' } @$args;
    }

    runx(EXIT_ANY, './checksetup.pl', @$args);
}

1;
