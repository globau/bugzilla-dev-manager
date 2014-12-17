package Bz::App::Command::fix;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "fixes an instance";
}

sub usage_desc {
    return "fix [--all]";
}

sub opt_spec {
    return (
        [ "all|a", "refreshes/fixes all things, including cached data" ],
    );
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
    $current->delete_cache() if $opt->all;
    $current->fix();
}

1;
