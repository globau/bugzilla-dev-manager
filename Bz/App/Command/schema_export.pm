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
    return "bz schema_export <filename>";
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
    info("writing schema to '$filename'");
    write_file($filename, $schema);
}

1;
