package Bz::App::Command::commit;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "commits current changes";
}

sub usage_desc {
    return "bz commit <bug_id> [--me][--quick]";
}

sub opt_spec {
    return (
        [ "me", "ignore bug assignee when setting the patch author" ],
        [ "quick|q", "don't run tests before committing" ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    shift @$args if @$args && $args->[0] eq 'bug';
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

    die "this command does not support upstream bugzilla\n"
        unless $repo->url =~ m#webtools/bmo/bugzilla\.git$#;

    my @staged = $repo->staged_files();
    my @committed = $repo->committed_files();

    die "no files are staged or committed\n"
        unless @staged || @committed;

    die "refusing to commit to the production branch\n"
        if $repo->branch eq 'production';

    my $bug_id;
    if ($repo->is_workdir) {
        $bug_id = $repo->bug_id;
    } else {
        $bug_id = shift @$args;
    }
    $self->usage_error("missing <bug_id>")
        unless $bug_id;

    info("committing bug $bug_id");
    my $bug = Bz->bug($bug_id);
    $repo->test()
        unless $opt->quick;
    info('Bug ' . $bug->id . ': ' . $bug->summary);

    chdir($repo->path);
    if (@staged) {
        $repo->git(qw(diff --staged --stat));
    }
    if (@committed) {
        $repo->git('diff', '--stat', 'origin/' . $repo->branch, $repo->branch);
    }
    print "\n";

    $repo->git(qw(config --get remote.origin.url));

    if (@staged) {
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
    } else {
        return unless confirm("push?");
    }

    $repo->git('push');
}

1;
