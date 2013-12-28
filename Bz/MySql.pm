package Bz::MySql;
use Bz;
use Moo;

use DBI;

has _nothing => ( is => 'lazy' );

sub dbh {
    my ($class, $name, $args) = @_;
    my $config = Bz->config;
    my $uri = sprintf("DBI:mysql:database=%s;host=%s;port=%s", $name, $config->localconfig->db_host, $config->localconfig->db_port);
    return DBI->connect(
        $uri,
        $config->localconfig->db_user, $config->localconfig->db_pass,
        $args,
    );
}

sub database_exists {
    my ($class, $name) = @_;
    return $class->dbh($name, { RaiseError => 0, PrintError => 0 }) ? 1 : 0;
}

1;
