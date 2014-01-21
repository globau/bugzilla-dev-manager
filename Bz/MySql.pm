package Bz::MySql;
use Bz;
use Moo;

use DBI;

my %_cache;

sub dbh {
    my ($class, $database, $args) = @_;

    my %params;
    my $config = Bz->config->localconfig;
    foreach my $name (qw( db_host db_port db_user db_pass )) {
        if (exists $args->{$name}) {
            $params{$name} = delete $args->{$name};
        } else {
            $params{$name} = $config->$name;
        }
    }

    $args->{RaiseError} = 1 unless exists $args->{RaiseError};
    $args->{PrintError} = 1 unless exists $args->{PrintError};

    my $key = "$database $params{db_user}";
    if (!$_cache{$key}) {
        $_cache{$key} = DBI->connect(
            "DBI:mysql:database=$database;host=$params{db_host};port=$params{db_port}",
            $params{db_user}, $params{db_pass},
            $args,
        );
        $_cache{$key}->do('SET NAMES utf8');
    }
    return $_cache{$key};
}

sub database_exists {
    my ($class, $database) = @_;
    my $result = 0;
    eval {
        $class->dbh($database);
        $result = 1;
    };
    return $result;
}

1;
