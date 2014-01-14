package Bz::App::Command::boiler_plate;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    bp
);

# XXX support --all

sub abstract {
    return "adds boiler-plates to new files";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current();
    my @files = grep { !Bz->boiler_plate->exists($_) } $current->added_files();
    die "no new files with missing boiler-plates\n" unless @files;

    warning("add boiler-plate to:");
    foreach my $file (@files) {
        next unless confirm("$file ?");
        Bz->boiler_plate->add($file);
    }

}

1;
