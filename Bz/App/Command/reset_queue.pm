package Bz::App::Command::reset_queue;
use Bz::App -command;
use Bz;

sub command_names {
    qw(
        reset_queue
        reset-queue
        reset_email_queue
        reset-email-queue
    );
}

sub abstract {
    return "resets the backoff for email, to force email to be sent on the next run";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    info("resetting email queue on " . $workdir->db);
    my $dbh = $workdir->dbh;
    $dbh->do("UPDATE ts_job SET grabbed_until = 0, insert_time = 0, run_after = 0");
}

1;
