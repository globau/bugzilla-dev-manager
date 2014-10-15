package Bz::App::Command::add;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "adds modified files to git's staging area";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $current = Bz->current;

    info("staging new or modified files");

    $current->unfix()
        if $current->is_workdir;

    my @new = $current->new_files();
    my @modified = $current->modified_files();

    @new = grep { !/\.(patch|orig)$/ } @new;

    unless (@new || @modified) {
        alert("no new or modified files");
    } else {
        my @files = (@modified, @new);
        list(\@new, \@modified);
        while (my $key = prompt('stage [y/n/d/l]?', 'yndl')) {
            last unless defined $key;
            if ($key eq 'd') {
                foreach my $file (@new) {
                    $current->git('diff', '/dev/null', $file);
                }
                $current->git('diff');
            } elsif ($key eq 'l') {
                list(\@new, \@modified);
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

sub list {
    my ($new, $modified) = @_;
    if (@$new) {
        alert("new file" . (scalar(@$new) == 1 ? '' : 's') . ":");
        foreach my $file (@$new) {
            warning($file);
        }
    }
    if (@$modified) {
        alert("modified file" . (scalar(@$modified) == 1 ? '' : 's') . ":");
        foreach my $file (@$modified) {
            warning($file);
        }
    }
}

1;
