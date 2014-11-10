package Bz::MySql;
use Bz;
use Moo;

use DBI;

my %_dbi_cache;

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
    if (!$_dbi_cache{$key}) {
        my $dsn = "DBI:mysql:database=$database;host=$params{db_host};port=$params{db_port}";
        $_dbi_cache{$key}{dbh} = DBI->connect(
            $dsn,
            $params{db_user}, $params{db_pass},
            $args,
        );
        $_dbi_cache{$key}->{dsn} = $dsn;
        $_dbi_cache{$key}->{dbh}->do('SET NAMES utf8');
    }
    return $_dbi_cache{$key}->{dbh};
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

package DBI::db;

sub dsn {
    my ($self) = @_;
    foreach my $key (keys %_dbi_cache) {
        return $_dbi_cache{$key}->{dsn}
            if $_dbi_cache{$key}->{dbh} eq $self;
    }
    return undef;
}

1;
