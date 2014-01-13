package Bz::App::Command::patch;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "downloads and applies a patch";
}

sub usage_desc {
    # XXX support --all to include obsolete patches
    return "bz %o [bug_id]";
}

sub description {
    return <<EOF;
XXX
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current();
    if ($current->isa('Bz::Workdir')) {
        my $bug_id = $current->bug_id ? $current->bug_id : $args->[0];
        die $self->usage_error('missing bug_id') unless $bug_id;
        $self->_patch($current, $bug_id);

    } else {
        # XXX repo
        die "invalid working directory\n";
    }
}

sub _patch {
    my ($self, $workdir, $bug_id) = @_;

    info("fetching patches from bug $bug_id:");
    message($bug_id == $workdir->bug_id ? $workdir->summary : $workdir->bug->summary);
    my @patches = (
        grep { $_->{is_patch} && !$_->{is_obsolete} }
        @{ Bz->bugzilla->attachments($bug_id) }
    );
    die "no patches found\n" unless @patches;
    die "too many patches found\n" if scalar(@patches) > 10;

    my $prompt = "  0. cancel\n";
    my $re = '0';
    for(my $i = 1; $i <= scalar @patches; $i++) {
        $prompt .= sprintf(" %2s. %s\n", $i, $patches[$i - 1]->{summary});
        $re .= "$i";
    }
    $prompt .= '? ';
    my $no = prompt($prompt, qr/[$re]/i);
    exit if $no == 0;
    my $attach_id = $patches[$no - 1]->{id};

    info("patching " . $workdir->dir . " with #$attach_id");
    my $filename = $workdir->download_patch($attach_id);
    $workdir->apply_patch($filename);
}

1;
