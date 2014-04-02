package Bz::App::Command::add;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "adds modified files to git's staging area";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $current = Bz->current;

    info("staging modified files");

    $current->unfix()
        if $current->is_workdir;

    my @files = $current->modified_files();
    if (!@files) {
        alert("no modified files");
    } else {
        alert("modified file" . (scalar(@files) == 1 ? '' : 's') . ":");
        foreach my $file (@files) {
            warning($file);
        }
        while (my $key = lc(prompt('stage [y/n/d]?', qr/[ynd]/i))) {
            if ($key eq 'd') {
                $current->git('diff');
            } else {
                $current->git('add', @files)
                    if $key eq 'y';
                last;
            }
        }
    }

    $current->fix()
        if $current->is_workdir;
}

1;
