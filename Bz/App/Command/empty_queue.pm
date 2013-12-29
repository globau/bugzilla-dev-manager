package Bz::App::Command::empty_queue;
use Bz::App -command;
use Bz;

sub command_names {
    qw(
        empty_queue
        empty-queue
        empty_email_queue
        empty-email-queue
    );
}

sub abstract {
    return "deletes all emails from the email queue";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    info("emptying email queue on " . $workdir->db);
    my $dbh = $workdir->dbh;
    $dbh->do("DELETE FROM ts_job");
}

1;
