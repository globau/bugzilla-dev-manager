package Bz::App::Command::disable_bugmail;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "disable bugmail for most accounts";
}

sub description {
    return <<EOF;
updates all profiles to disable bugmail and removes the cc_list for all
flagtypes.

users listed in the config file's never_disable_bugmail will not have their
email disabled.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    info("disabling bugmail on " . $workdir->db);
    my $dbh = $workdir->dbh;
    $dbh->do("UPDATE profiles SET disable_mail=1");
    $dbh->do("UPDATE flagtypes SET cc_list=''");

    my $never_disable = Bz->config->never_disable_bugmail;
    if ($never_disable && @$never_disable) {
        $dbh->do("UPDATE profiles SET disable_mail=0 WHERE login_name IN ('" . join("','", @$never_disable) . "')");
    }
}

1;
