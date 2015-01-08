package Bz::App::Command::interdiff;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "executes interdiff on the two most recently generated patches.";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    chdir($workdir->path);
    my @files =
        sort {
            my ($a_i) = $a =~ /^[^_]+_(\d+)/;
            my ($b_i) = $b =~ /^[^_]+_(\d+)/;
            $a_i <=> $b_i;
        }
        glob($workdir->dir . '_*.patch');
    if (!@files) {
        @files =
            sort {
                my ($a_i) = $a =~ /^\d+-(\d+)/;
                my ($b_i) = $b =~ /^\d+-(\d+)/;
                $a_i <=> $b_i;
            }
            grep { /^\d+-\d+\.patch$/ }
            glob(($workdir->bug_id ? $workdir->bug_id : $workdir->dir) . '*.patch');
    }
    splice(@files, 0, -2);

    # if the only patch is one that we fetched from a bug, automatically
    # download the last patch
    if (scalar @files == 1 && $files[0] =~ /^\d+-\d+\.patch$/ && $workdir->bug_id) {
        message("looking for a previous patch");
        my ($current_attach_id) = $files[0] =~ /^\d+-(\d+)/;
        my @patches =
            sort { $a->{id} <=> $b->{id} }
            grep { $_->{is_patch} }
            grep { $_->{id} != $current_attach_id }
            @{ Bz->bugzilla->attachments($workdir->bug_id) };
        if (my $patch = pop @patches) {
            my $filename = $workdir->download_patch($patch->{id});
            unshift @files, $filename;
        }
    }

    die "failed to find 2 patches\n" unless scalar(@files) == 2;
    info("interdiff'ing @files");
    system "interdiff @files";
}

1;
