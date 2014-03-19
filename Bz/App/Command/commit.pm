package Bz::App::Command::commit;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "commits current changes";
}

sub usage_desc {
    return "bz commit <bug_id> [--me]";
}

sub opt_spec {
    return (
        [ "me", "ignore bug assginee when setting the patch author" ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    shift @$args if @$args && $args->[0] eq 'bug';
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

    die "no files are staged\n"
        unless $repo->staged_files();

    info("committing bug " . $args->[0]);
    my $bug = Bz->bug($args->[0]);
    $repo->test();
    info('Bug ' . $bug->id . ': ' . $bug->summary);

    chdir($repo->path);
    $repo->git(qw(diff --staged --stat));

    print "\n";
    my @args = (
        'commit',
    );
    message('git commit');

    my $author = '';
    if (lc($bug->assignee) ne lc(Bz->config->bmo_username)
        && $bug->assignee ne 'nobody@mozilla.org'
        && !$opt->me
    ) {
        my $user = Bz->bugzilla->user($bug->assignee);
        push @args, (
            "--author=" . $user->{name} . " <" . $bug->assignee . ">",
        );
        message('  ' . $args[-1]);
    }

    push @args, (
        '-m', 'Bug ' . $bug->id . ': ' . $bug->summary,
    );
    message('  -m "' . $args[-1] . '"');
    message('git push');

    return unless confirm("commit and push?");
    $repo->git(@args);
    $repo->git('push');
}

1;
