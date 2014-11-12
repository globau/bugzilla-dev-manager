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
    my $workdir = Bz->current_workdir;
    chdir($workdir->path);

    silent {
        $workdir->unfix();
    };

    my @files = ($workdir->staged_files(), $workdir->modified_files());
    unless (@files) {
        silent {
            $workdir->fix();
        };
        die "no files are modified or staged\n"
    }

    my @command = ('diff');
    push @command, '-w' if $opt->whitespace;

    foreach my $file ($workdir->new_files) {
        next if $file =~ /\.patch$/;
        $workdir->git(@command, '/dev/null', $file);
    }

    $workdir->git(@command);
    push @command, '--staged';
    $workdir->git(@command);

    silent {
        $workdir->fix();
    };
}

1;
