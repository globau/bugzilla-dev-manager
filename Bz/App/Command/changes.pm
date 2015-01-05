package Bz::App::Command::changes;
use parent 'Bz::App::Base';
use Bz;

use File::Slurp;

use constant ALIASES => qw(
    changed
);

sub abstract {
    return "generate a diff of just the changes";
}

sub usage_desc {
    return "bz changes [--whitespace]";
}

sub opt_spec {
    return (
        [ "whitespace|w",   "ignore whitespace" ],
    );
}

sub description {
    return <<EOF;
generates a diff of all changes (modified and staged).
does not run any tests.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $repo = Bz->current_repo;
    chdir($repo->path);

    silent {
        $repo->unfix();
    };

    my @files = ($repo->staged_files(), $repo->modified_files());
    unless (@files) {
        silent {
            $repo->fix();
        };
        die "no files are modified or staged\n"
    }

    my @command = ('diff');
    push @command, '-w' if $opt->whitespace;

    foreach my $file ($repo->new_files) {
        next if $file =~ /\.patch$/;
        $repo->git(@command, '/dev/null', $file);
    }

    $repo->git(@command);
    push @command, '--staged';
    $repo->git(@command);

    silent {
        $repo->fix();
    };
}

1;
