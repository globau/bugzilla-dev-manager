package Bz::App::Command::fix;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "XXX";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current();
    info("fixing $current");
    $current->fix();
}

1;
