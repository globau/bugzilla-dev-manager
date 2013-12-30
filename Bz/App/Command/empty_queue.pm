package Bz::App::Command::empty_queue;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    emtpy_email_queue
);

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
