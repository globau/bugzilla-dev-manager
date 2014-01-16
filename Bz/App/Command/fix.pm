package Bz::App::Command::fix;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "fixes an instance";
}

sub description {
    return <<EOF;
performs several changes to make an instance work within the environment.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current();
    info("fixing $current");
    $current->fix();
}

1;
