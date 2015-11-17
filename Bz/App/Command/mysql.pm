package Bz::App::Command::mysql;
use parent 'Bz::App::Base';
use Bz;

use IPC::System::Simple qw( runx );

sub abstract {
    return "starts the mysql client connecting to the current instance's database";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $config = $workdir->localconfig();

    my @command = ('mysql', '-h', $config->{db_host});
    push @command, ('-P', $config->{db_port}) if $config->{db_port};
    push @command, ('-u', $config->{db_user});
    push @command, ('-p' . $config->{db_pass});
    push @command, $config->{db_name};

    runx(@command, @$args);
}

1;
