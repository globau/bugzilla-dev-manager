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
    my $current = Bz->current;
    chdir($current->path);

    silent {
        $current->unfix();
    };

    my @files = ($current->staged_files(), $current->modified_files());
    unless (@files) {
        silent {
            $current->fix();
        };
        die "no files are modified or staged\n"
    }

    my @command = ('diff');
    push @command, '-w' if $opt->whitespace;

    foreach my $file ($current->new_files) {
        next if $file =~ /\.patch$/;
        $current->git(@command, '/dev/null', $file);
    }

    $current->git(@command);
    push @command, '--staged';
    $current->git(@command);

    silent {
        $current->fix();
    };
}

1;
