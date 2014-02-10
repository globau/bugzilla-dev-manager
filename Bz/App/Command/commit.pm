package Bz::App::Command::commit;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "commits current changes";
}

sub usage_desc {
    return "bz commit <bug_id>";
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    $self->usage_error("missing <bug_id>") unless @$args;
}

sub description {
    return <<EOF;
commits the current changes, using the specified bug id and using that bug's
summary as the commit message.

this comment only works from a repo, not a development instance.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $repo = Bz->current;
    die "unable to commit from a development instance\n"
        if $repo->is_workdir;

    info("committing bug " . $args->[0]);
    my $bug = Bz->bug($args->[0]);
    $repo->test();
    info('Bug ' . $bug->id . ': ' . $bug->summary);

    chdir($repo->path);
    $repo->bzr('st');

    my @args = (
        'commit',
        '--fixes', 'mozilla:' . $bug->id,
    );
    info('bzr commit');
    info('  ' . $args[-2] . ' ' . $args[-1]);

    my $author = '';
    if (lc($bug->assignee) ne lc(Bz->config->bmo_username)) {
        my $user = Bz->bugzilla->user($bug->assignee);
        push @args, (
            "--author=" . $user->{name} . " <" . $bug->assignee . ">",
        );
        info('  ' . $args[-1]);
    }

    push @args, (
        '-m', 'Bug ' . $bug->id . ': ' . $bug->summary,
    );
    info('  -m "' . $args[-1] . '"');

    return unless confirm("commit?");
    $repo->bzr(@args);
}

1;
