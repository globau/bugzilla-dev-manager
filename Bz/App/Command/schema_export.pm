package Bz::App::Command::schema_export;
use parent 'Bz::App::Base';
use Bz;

use File::Slurp;

use constant ALIASES => qw(
    export_schema
);

sub abstract {
    return "exports bz_schema to the specified file";
}

sub usage_desc {
    return "bz schema_export <filename> [--json]";
}

sub opt_spec {
    return (
        [ "json|j", "export as json instead of Data::Dumper" ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <filename>") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $filename = $args->[0];
    my $dbh = $workdir->bz_dbh;
    my ($schema) = $dbh->selectrow_array("SELECT schema_data FROM bz_schema");

    if ($opt->json) {
        require Safe;
        my $cpt = Safe->new();
        $cpt->reval($schema)
            || die "invalid schema file: " . $@;
        require JSON::PP;
        my $json = JSON::PP->new
            ->utf8
            ->pretty
            ->indent_length(2)
            ->space_before(0)
            ->canonical;
        $schema = $json->encode(${ $cpt->varglob('VAR1') });
    }

    if ($filename eq '-') {
        print $schema;
    } else {
        info("writing schema to '$filename'");
        write_file($filename, $schema);
    }
}

1;
