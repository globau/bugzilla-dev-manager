package Bz::App::Command::drop_column;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "drops the specified column from schema and bz_schema";
}

sub usage_desc {
    return "bz drop-column <table>.<column> [<table>.<column>..]";
}

sub description {
    return <<'EOF';
drops the specified column from the schema and updates bz_schema.
EOF
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <table>.<column>") unless @$args;
    foreach my $arg (@$args) {
        $self->usage_error("invalid column '$arg'") unless $arg =~ /^.+\..+$/;
    }
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;
    my $dbh = $workdir->dbh;
    my $database = $workdir->db;

    my @columns;
    foreach my $arg (@$args) {
        my ($table, $column) = $arg =~ /^([^\.]+)\.(.+)$/;
        my ($exists) = $dbh->selectrow_array("
            SELECT 1
              FROM information_schema.columns
             WHERE table_schema = '$database'
                   AND table_name = '$table'
                   AND column_name = '$column'
        ");
        if ($exists) {
            exit unless confirm("are you sure you want to drop the column '$table.$column'?");
        }
        push @columns, { table => $table, column => $column, exists => $exists };
    }

    message("loading schema");
    chdir($workdir->path);
    my $bz_dbh = $workdir->bz_dbh;
    my $schema = $bz_dbh->_bz_real_schema;

    foreach my $rh (@columns) {
        my ($table, $column) = ($rh->{table}, $rh->{column});
        if (!exists $schema->{abstract_schema}->{$table}) {
            die "failed to find table '$table' in bz_schema\n";
        }
        my $table_schema = $schema->{abstract_schema}->{$table};
        my @fields = @{$table_schema->{FIELDS}};
        my $found = 0;
        for (my $i = 0; $i < scalar(@fields); $i += 2) {
            my ($name, $rh) = @fields[$i, $i + 1];
            if ($name eq $column) {
                $found = 1;
                last;
            }
        }
        if (!$found) {
            die "failed to find column '$column' in table '$table' in bz_schema\n";
        }
    }

    foreach my $rh (@columns) {
        my ($table, $column, $exists) = ($rh->{table}, $rh->{column}, $rh->{exists});
        my $table_schema = $schema->{abstract_schema}->{$table};
        my @fields = @{$table_schema->{FIELDS}};
        info("dropping '$table.$column'");
        $dbh->do("ALTER TABLE $table DROP COLUMN $column") if $exists;
        my @new_fields;
        for (my $i = 0; $i < scalar(@fields); $i += 2) {
            my ($name, $rh) = @fields[$i, $i + 1];
            if ($name ne $column) {
                push @new_fields, ($name, $rh);
            }
        }
        $schema->{abstract_schema}->{$table}->{FIELDS} = \@new_fields;
    }

    message("updating bz_schema");
    $bz_dbh->_bz_store_real_schema();
}

1;
