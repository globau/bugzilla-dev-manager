package Bz::App::Command::drop_table;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "drops the specified table from schema and bz_schema";
}

sub usage_desc {
    return "bz drop-table <table> [<table>..]";
}

sub description {
    return <<'EOF';
drops the specified table from the schema and updates bz_schema.
EOF
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <table>") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;
    my $dbh = $workdir->dbh;
    my $database = $workdir->db;

    foreach my $table (@$args) {
        my ($exists) = $dbh->selectrow_array("
            SELECT 1
              FROM information_schema.tables
             WHERE table_schema = '$database'
                   AND table_name = '$table'
        ");
        if ($exists) {
            exit unless confirm("are you sure you want to drop the table '$table'?");
        }
    }

    message("loading schema");
    chdir($workdir->path);
    my $bz_dbh = $workdir->bz_dbh;
    my $schema = $bz_dbh->_bz_real_schema;

    foreach my $table (@$args) {
        if (!exists $schema->{abstract_schema}->{$table}) {
            alert("failed to find table '$table' in bz_schema");
        }
    }
    foreach my $table (@$args) {
        info("dropping table '$table'");
        $dbh->do("DROP TABLE $table");
        delete $schema->{abstract_schema}->{$table};
    }

    message("updating bz_schema");
    $bz_dbh->_bz_store_real_schema();
}

1;
