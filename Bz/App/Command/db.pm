package Bz::App::Command::db;
use Bz::App -command;
use Bz;

sub abstract {
    return "get or set the database";
}

sub usage_desc {
    return "bz [db]";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $workdir = Bz->current_workdir;

    if (my $db = shift(@$args)) {
        my $current_db = $workdir->db;
        $workdir->db($db);
        if ($workdir->db eq $current_db) {
            die "database is already " . $workdir->db . "\n";
        }
        info("changing database to " . $workdir->db);
        $workdir->check_db();
        $workdir->update_localconfig();
        $workdir->fix_params();

    } else {
        info("database for " . $workdir->dir . " is " . $workdir->db);
    }
}

1;
