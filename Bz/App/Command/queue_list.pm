package Bz::App::Command::queue_list;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    list_queue
    list_email_queue
);

sub abstract {
    return "lists jobs in the email queue";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $dbh = $workdir->dbh;

    my $jobs = $dbh->selectall_arrayref("
        SELECT jobid, insert_time, run_after, funcname
          FROM ts_job
               INNER JOIN ts_funcmap ON ts_funcmap.funcid = ts_job.funcid
         ORDER BY insert_time, jobid
    ", { Slice => {} });

    info(scalar(@$jobs) . " job" . (@$jobs == 1 ? '' : 's') . ' on ' . $workdir->db);
    if (@$jobs) {
        $Data::Dumper::Terse = 1;
        message(Dumper($jobs));
    }
}

1;
