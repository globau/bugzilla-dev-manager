package Bz::App::Command::reset_password;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "changes the password of a bugzilla user, without running full checksetup";
}

sub usage_desc {
    return "reset_password <login>";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <login>") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $login = $args->[0];
    info("resetting password for $login");

    chdir($workdir->path);
    require Bugzilla;
    require Bugzilla::Install;
    Bugzilla::Install::reset_password($login);
}

1;
