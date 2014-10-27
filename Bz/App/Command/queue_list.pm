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
        SELECT jobid, insert_time, run_after, grabbed_until, funcname
          FROM ts_job
               INNER JOIN ts_funcmap ON ts_funcmap.funcid = ts_job.funcid
         ORDER BY insert_time, jobid
    ", { Slice => {} });

    info(scalar(@$jobs) . " job" . (@$jobs == 1 ? '' : 's') . ' on ' . $workdir->db);
    if (@$jobs) {
        print "current time: ", _date(time()), "\n";
        printf "%7s | %-19s | %-19s | %-19s\n",
            'type',
            'inserted',
            'after aftert',
            'grabbed until'
        ;
    }
    foreach my $job (@$jobs) {
        (my $func = $job->{funcname}) =~ s/^Bugzilla::Job:://;
        printf "%7s | %19s | %19s | %19s\n",
            $func,
            _date($job->{insert_time}),
            _date($job->{run_afer}),
            _date($job->{grabbed_until})
        ;
    }
}

sub _date {
    my ($epoch) = @_;
    return '-' unless $epoch;
    my $date = DateTime->from_epoch(epoch => $epoch);
    return $date->ymd('-') . ' ' . $date->hms(':');
}

1;
