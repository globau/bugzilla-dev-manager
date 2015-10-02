package Bz::App::Command::patch;
use parent 'Bz::App::Base';
use Bz;

use Bz::Util 'coloured';
use File::Slurp 'read_file';
use LWP::Simple;
use URI;
use URI::QueryParam;

sub abstract {
    return "downloads and applies a patch";
}

sub usage_desc {
    return "bz patch [bug_id|source_url|file] [--last] [--all] [--download] [--test] [--patch]";
}

sub opt_spec {
    return (
        [ "last|l",       "apply the last/latest patch without prompting" ],
        [ "all|a",        "list all patches" ],
        [ "download|d",   "download patch, but don't apply" ],
        [ "test|t",       "run tests after applying patch" ],
        [ "patch|p",      "use 'patch' instead of 'git' to apply the patch" ],
    );
}

sub validate_args {
    my ($self, $opt, $args) = @_;
    shift @$args if @$args && $args->[0] eq 'bug';
}

sub description {
    return <<EOF;
downloads and applies a patch from the specified bug or source.

if the current instance's directory name is a bug id, that bug will be queried
for attachments.  when executed from a repo the bug_id is required.

you can provide an url to a diff instead of a bug id.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current();
    my $source;
    $source = shift @$args
        if @$args && $args->[0] !~ /^-/;
    $source ||= $current->is_workdir ? $current->bug_id : undef;
    die $self->usage_error('missing bug_id or source') unless $source;

    if (!$opt->download) {
        message('checking for local changes');
        silent {
            $current->unfix();
        };
        my @files = ($current->staged_files(), $current->modified_files());
        silent {
            $current->fix();
        };
        if (@files) {
            return unless confirm("repo has local changes, continue?");
        }
    }

    my $filename;
    my $delete = 1;
    if (-e $source) {
        $filename = $source;
        $delete = 0;

    } elsif ($source =~ m#^https?://#) {
        my $uri = URI->new($source)
            or die "invalid url: $source\n";
        my @segments = $uri->path_segments();
        if (@segments) {
            $filename = pop(@segments);
        } else {
            $filename = $uri->host;
        }
        if ($filename eq 'attachment.cgi') {
            if ($current->is_workdir) {
                $filename = $current->bug_id . '-' . $uri->query_param('id') . '.patch';
            } else {
                $filename = $uri->query_param('id') . '.patch';
            }
        } else {
            $filename ||= 'download.patch';
            $filename .= '.patch' unless $filename =~ /\./;
        }
        message("downloading $uri to $filename");
        getstore($uri, $filename);

    } elsif ($source !~ /\D/) {
        my $bug_id = $source;
        message("fetching patches from bug $bug_id");
        my $summary;
        if ($current->is_workdir) {
            $summary = $current->summary if $current->bug_id && $bug_id == $current->bug_id;
        }
        info($summary || Bz->bug($bug_id)->summary);

        my @patches = @{ Bz->bugzilla->attachments($bug_id) };
        if (!$opt->all) {
            @patches = grep { $_->{is_patch} && !$_->{is_obsolete} } @patches;
        }
        die "no patches found\n" unless @patches;
        die "too many patches found\n" if scalar(@patches) > 10;

        my $prompt = "  0. cancel\n";
        my @options = ('0');
        for(my $i = 1; $i <= scalar @patches; $i++) {
            my $patch = $patches[$i - 1];
            $prompt .= sprintf(
                " %2s. %s %s\n",
                $i,
                $patch->{summary},
                ($opt->all && $patch->{is_obsolete} ? '[obsolete]' : ''),
            );
            push @options, $i;
        }
        $prompt .= '? ';
        my $num;
        if ($opt->last) {
            $num = $options[$#options];
            print coloured($prompt, 'yellow') . "$num\n";
        } else {
            $num = prompt($prompt, join('', @options));
        }
        exit unless $num;
        my $attach_id = $patches[$num - 1]->{id};

        if (!$opt->download) {
            info("patching " . $current->dir . " with #$attach_id");
        }
        $filename = $current->download_patch($attach_id);
    } else {
        die "unrecognised source: $source\n";
    }

    if (!$opt->download) {
        my @patch = read_file($filename);
        my $is_git = 0;
        foreach my $line (@patch) {
            if ($line =~ /^diff --git a\//) {
                $is_git = 1;
                last;
            }
        }

        chdir($current->path);
        if (!$opt->patch) {
            $current->git('apply', '-p', ($is_git ? '1' : '0'), '--verbose', $filename);
            if ($IPC::System::Simple::EXITVAL) {
                die "patch failed to apply\n";
            }
        } else {
            open(my $patch, "|patch -p" . ($is_git ? '1' : '0'));
            foreach my $line (@patch) {
                # === renamed file 'extensions/BMO/web/js/choose_product.js' => 'extensions/BMO/web/js/prod_comp_search.js'
                if ($line =~ /^=== renamed file '([^']+)' => '([^']+)'/) {
                    message("renamed '$1' => '$2'");
                    rename($1, $2);
                    next;
                }
                print $patch $line;
            }
            close($patch);
        }

        if (!$current->is_workdir && $delete) {
            info("deleting $filename");
            unlink($filename);
        } elsif ($opt->test) {
            info("running tests");
            $current->test();
        }
    }
}

1;
