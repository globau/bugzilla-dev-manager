package Bz::App::Command::mysql;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "starts the mysql client connecting to the current instance's database";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $config = $workdir->localconfig();

    my $cmd = "mysql -h $config->{db_host} ";
    $cmd .= "-P $config->{db_port} " if $config->{db_port};
    $cmd .= "-u $config->{db_user} -p$config->{db_pass} ";
    $cmd .= $config->{db_name};

    system($cmd);
}

1;
