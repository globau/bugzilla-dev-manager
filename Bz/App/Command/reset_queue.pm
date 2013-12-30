package Bz::App::Command::reset_queue;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    reset_email_queue
);

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
