package Bz::App::Command::mysql_trace;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "toggles mysql's logging of every query";
}

sub description {
    return <<'EOF';
toggles mysql's logging of every query by setting the 'general_log' variable.

requires a root user with an empty password.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;
    my $dbh = Bz->current_workdir->dbh({ db_user => 'root', db_pass => '' });

    my (undef, $value) = $dbh->selectrow_array("SHOW VARIABLES LIKE 'general_log'");
    my (undef, $filename) = $dbh->selectrow_array("SHOW VARIABLES LIKE 'general_log_file'");
    if ($value eq 'ON') {
        info("disabling logging to $filename");
        $value = 'OFF';
    } else {
        info("enabling logging to $filename");
        $value = 'ON';
    }
    $dbh->do("SET GLOBAL general_log='$value'");
}

1;
