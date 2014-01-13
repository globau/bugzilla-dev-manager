package Bz::App::Command::boiler_plate;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    bp
);

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
    foreach my $file ($current->added_files()) {
        print "$file\n";
    }
}

1;
