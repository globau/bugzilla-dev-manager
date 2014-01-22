package Bz::App::Command::test;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "run test suite";
}

sub usage_desc {
    return "bz test [--verbose] [test number][..]";
}

sub opt_spec {
    return (
        [ "verbose|v",  "verbose output" ],
    );
}

sub description {
    return <<EOF;
performs sanity checking, and if appropriate runs the bugzilla test suite.

if the current directory is a repository checkout, then just a set of simple
checks are performed (checking for tabs, new files not added to bzr, common
mistakes, etc).

if the current directory is a working instance, then the bugzilla test suite
will also be executed.

without arguments all tests will run.  passing one or more number will cause
only those tests to be executed.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current_workdir();
    info("running tests");
    $current->test($opt, $args);
}

1;
