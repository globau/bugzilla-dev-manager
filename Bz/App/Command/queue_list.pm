package Bz::App::Command::queue_list;
use parent 'Bz::App::Base';
use Bz;

use DateTime;

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
    foreach my $job (@$jobs) {
        (my $func = $job->{funcname}) =~ s/^Bugzilla::Job:://;
        my $insert = DateTime->from_epoch(epoch => $job->{insert_time});
        my $after  = DateTime->from_epoch(epoch => $job->{run_after});
        printf "%s | %s | %s\n",
            $func,
            $insert->ymd('-') . ' ' . $insert->hms(':'),
            $after->ymd('-') . ' ' . $after->hms(':'),
        ;
    }
}

1;
