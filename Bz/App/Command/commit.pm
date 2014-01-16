package Bz::App::Command::commit;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "commits current changes";
}

sub usage_desc {
    return "commit <bug_id>";
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
        if $repo->isa('Bz::Workdir');

    info("committing bug " . $args->[0]);
    my $bug = Bz->bug($args->[0]);
    $repo->test();
    my $message = 'Bug ' . $bug->id . ': ' . $bug->summary;

    chdir($repo->path);
    $repo->bzr('st');
    info(sprintf("bzr commit --fixes mozilla:%s -m '%s'", $bug->id, $message));
    return unless confirm("commit?");
    $repo->bzr(
        'commit',
        '--fixes', 'mozilla:' . $bug->id,
        '-m', 'Bug ' . $bug->id . ': ' . $bug->summary,
    );
}

1;
