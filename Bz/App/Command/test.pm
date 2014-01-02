package Bz::App::Command::test;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "run test suite";
}

sub usage_desc {
    return "test [--verbose] [test number][..]";
}

sub opt_spec {
    return (
        [ "verbose|v",  "verbose output" ],
    );
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    if (my $workdir = eval { Bz->current_workdir }) {
        info("running tests");
        $workdir->test($opt, $args);
        return;
    }

    # XXX check for repo

    die "invalid working directory\n";
}

1;
