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
after confirmation, an mpl2 boiler-plate will added to new files which are
missing the license.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $current = Bz->current();

    my @files;

    if (@$args) {
        @files = @$args;
    } else {
        $current->unfix();
        @files = grep { -f $_ && !-B $_ && !/\.(?:patch|htaccess)$/ } (
            $current->new_files,
            $current->modified_files,
            $current->staged_files,
            $current->added_files
        );
        $current->fix();
    }

    @files = grep { !Bz->boiler_plate->exists($_) } @files;
    die "no files with missing boiler-plates\n" unless @files;

    warning("add boiler-plate to:");
    foreach my $file (@files) {
        next unless confirm("$file ?");
        Bz->boiler_plate->add($file);
    }

}

1;
