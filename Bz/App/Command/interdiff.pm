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
            glob($workdir->dir . '*.patch');
    }
    splice(@files, 0, -2);
    die "failed to find 2 patches\n" unless scalar(@files) == 2;
    info("interdiff'ing @files");
    system "interdiff @files";
}

1;
