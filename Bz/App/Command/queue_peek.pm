package Bz::App::Command::queue_peek;
use parent 'Bz::App::Base';
use Bz;

use DateTime;

use constant ALIASES => qw(
    peek_queue
    peek_email_queue
);

sub usage_desc {
    return "bz queue-peek <jobid>";
}

sub abstract {
    return "prints the payload for the specified jobid in the queue";
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <jobid>") unless @$args;
    $self->usage_error("invalid <jobid>") unless $args->[0] =~ /^\d+$/;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $job_id = $args->[0];

    my $dbh = $workdir->dbh;

    require 'TheSchwartz.pm';
    my $config = Bz->config->localconfig;
    my $ts = TheSchwartz->new(
        databases => [{
            dsn     => $dbh->dsn,
            user    => $config->db_user,
            pass    => $config->db_pass,
            prefix  => 'ts_',
        }],
    );

    foreach my $hash_dsn ($ts->shuffled_databases) {
        my $driver = $ts->driver_for($hash_dsn);
        my $job = $driver->lookup('TheSchwartz::Job', $job_id)
            or die "failed to find job with id '$job_id'\n";
        local $Data::Dumper::Terse = 1;
        print Dumper($job->arg);
        last;
    }
}

1;
