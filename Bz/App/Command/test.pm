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

    my $current = Bz->current();
    info("running tests");
    # XXX ensure repo tests work
    $current->test($opt, $args);
}

1;
