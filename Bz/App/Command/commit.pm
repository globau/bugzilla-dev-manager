package Bz::App::Command::commit;
use parent 'Bz::App::Base';
use Bz;

use File::Temp;

sub abstract {
    return "commits current changes";
}

sub usage_desc {
    return "bz commit <bug_id> [--me][--quick][--edit]";
}

sub opt_spec {
    return (
        [ "me", "ignore bug assignee when setting the patch author" ],
        [ "quick|q", "don't run tests before committing" ],
        [ "edit|e", "edit the commit message" ],
        [ "force|f", "allow committing of unassigned bugs" ],
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

    my $edit = $repo->is_upstream || $opt->edit;
    my $temp_file;

    my @staged = $repo->staged_changes();
    my @committed = $repo->committed_files();

    die "no files are staged or committed\n"
        unless @staged || @committed;

    die "refusing to commit to the production branch\n"
        if $repo->branch eq 'production';

    my $bug_id;
    if ($repo->is_workdir && $repo->bug_id) {
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

    if (!$opt->force
        && ($bug->assignee eq 'nobody@mozilla.org' || $bug->assignee =~ /\.bugs$/)
    ) {
        die "cannot commit unassigned bugs\n";
    }

    chdir($repo->path);
    if (@staged) {
        $repo->git(qw(diff --staged --stat));
    }
    if (@committed) {
        $repo->git('diff', '--stat', 'origin/' . $repo->branch, $repo->branch);
    }
    message('');

    $repo->git(qw(config --get remote.origin.url));
    message('* ' . $repo->branch);
    message('');

    if (@staged) {
        my @args = (
            'commit',
        );

        my $message = 'Bug ' . $bug->id . ' - ' . $bug->summary;
        if ($repo->is_upstream) {
            message("looking for reviewer");
            my $reviewer = '?';
            my $nicknames = Bz->config->nicknames;
            foreach my $attachment (reverse @{ Bz->bugzilla->attachments($bug->id) }) {
                next if $attachment->{is_obsolete};
                next unless my @flags = grep { $_->{status} eq '+' } @{ $attachment->{flags} };
                my $setter = lc($flags[0]->{setter});
                if (my $nick = $nicknames->get($setter)) {
                    $reviewer = $nick;
                } else {
                    warning("couldn't find nickname for reviewer $setter");
                }
                last;
            }
            $message .= "\nr=$reviewer,a=?";
        }

        message('git commit');

        my $author = '';
        if (lc($bug->assignee) ne lc(Bz->config->bmo_username)
            && $bug->assignee ne 'nobody@mozilla.org'
            && !$opt->me
        ) {
            my $name = Bz->bugzilla->user($bug->assignee)->{name};
            $name =~ s/[\[\<\(][^\]\>\)]*[\]\>\)]/ /g;
            $name =~ s/\s+/ /g;
            $name =~ s/(^\s+|\s+$)//g;
            if ($name) {
                push @args, (
                    "--author=$name <" . $bug->assignee . ">",
                );
            } else {
                push @args, (
                    "--author=" . $bug->assignee,
                );
            }
            message('  ' . $args[-1]);
        }

        if (!$edit) {
            push @args, '-m', $message;
        }
        message("  -m '$message'");

        message('git push');
        return unless confirm(
            $edit
            ? "edit message, commit, and push?"
            : "commit and push?"
        );

        if ($edit) {
            $temp_file = File::Temp->new();
            print $temp_file $message;
            close($temp_file);
            push @args, '-t', scalar($temp_file);
        }

        $repo->git(@args);
    } else {
        return unless confirm("push?");
    }

    $repo->git('push');
}

1;
