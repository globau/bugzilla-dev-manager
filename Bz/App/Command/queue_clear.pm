package Bz::App::Command::queue_clear;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    clear_queue
    clear_email_queue
);

sub abstract {
    return "deletes all queued email";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    info("clearing email queue on " . $workdir->db);
    my $dbh = $workdir->dbh;
    $dbh->do("DELETE FROM ts_job");
}

1;
