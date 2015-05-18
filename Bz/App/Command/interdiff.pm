package Bz::App::Command::interdiff;
use parent 'Bz::App::Base';
use Bz;

use IPC::System::Simple qw(runx capturex EXIT_ANY);

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
    return unless runx(EXIT_ANY, 'interdiff', @files);

    # interdiff failed, just diff the patches
    warning("interdiff failed, using standard diff");

    my @lines = capturex(EXIT_ANY, 'diff', '-u', @files);
    chomp(@lines);

    # read diff into file/hunks
    my @interdiff;
    my ($current_file, $current_hunk);
    foreach my $line (@lines) {
        if ($line =~ /^--- ([^\t]+)/) {
            $current_file = { name => $1, hunks => [], preamble => [ $line ] };
            undef $current_hunk;
            push @interdiff, $current_file;

        } elsif ($line =~ /^\@\@ /) {
            $current_hunk = [ $line ];
            push @{ $current_file->{hunks} }, $current_hunk;

        } elsif (!$current_hunk) {
            push @{ $current_file->{preamble} }, $line;

        } else {
            push @$current_hunk, $line;
        }
    }

    # remove files/hunks that only contain unimportant changes
    foreach my $file (@interdiff) {
        foreach my $hunk (@{ $file->{hunks} }) {
            my $has_content = 0;
            foreach my $line (@$hunk) {
                next unless $line =~ /^[\-\+]/;
                next if $line =~ /^-index / || $line =~ /^\+index /;
                next if $line =~ /-\@\@ / || $line =~ /^\+\@\@ /;
                $has_content = 1;
                last;
            }
            if (!$has_content) {
                $hunk = undef;
            }
        }
        $file->{hunks} = [ grep { defined } @{ $file->{hunks} } ];
    }
    @interdiff = grep { scalar(@{ $_->{hunks} }) } @interdiff;

    # display
    foreach my $file (@interdiff) {
        foreach my $line (@{ $file->{preamble} }) {
            print $line, "\n";
        }
        foreach my $hunk (@{ $file->{hunks} }) {
            foreach my $line (@$hunk) {
                $line =~ s/^(.)./$1/;
                print $line, "\n";
            }
        }
    }
}

1;
