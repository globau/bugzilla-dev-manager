package Bz::App::Command::xt;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "run xt test suite";
}

sub usage_desc {
    return "bz xt [--verbose]";
}

sub opt_spec {
    return (
        [ "verbose|v",  "verbose output" ],
    );
}

sub description {
    return <<EOF;
performs sanity checking, and runs the xt test suit, including tests which update the database.

as this test should be performed on an empty bugzilla database it will not start if any bugs are found in the database.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir();

    my $dbh = $workdir->dbh;
    my ($bug_count) = $dbh->selectrow_array("SELECT COUNT(*) FROM bugs");
    die "unable to execute xt tests on " . $workdir->db . " because the bugs table is not empty\n"
        if $bug_count;

    info("running tests");

    # if the tests die, bugs_fulltext isn't cleared, and can result in duplicate key errors
    $dbh->do('DELETE FROM bugs_fulltext');

    $ENV{BZ_WRITE_TESTS} = 1;
    $workdir->run_tests($opt, 'xt/search.t');
}

1;
