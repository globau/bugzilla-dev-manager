package Bz::App::Command::schema_import;
use parent 'Bz::App::Base';
use Bz;

use File::Slurp;
use Safe;

use constant ALIASES => qw(
    import_schema
);

sub abstract {
    return "imports bz_schema from the specified file";
}

sub usage_desc {
    return "bz schema_import <filename>";
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <filename>") unless @$args;
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my $filename = $args->[0];
    my $schema = read_file($filename);
    my $cpt = Safe->new();
    $cpt->reval($schema)
        || die "invalid schema file: " . $@;

    info("importing schema from $filename");
    my $dbh = $workdir->bz_dbh;
    my $sth = $dbh->prepare("UPDATE bz_schema SET schema_data = ?");
    $sth->bind_param(1, $schema, $dbh->BLOB_TYPE);
    $sth->execute();
}

1;
