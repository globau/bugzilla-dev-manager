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
    my @deleted = $current->deleted_files();

    @new = grep { !/\.(patch|orig)$/ } @new;

    unless (@new || @modified) {
        alert("no new, modified, or deleted files");
    } else {
        list(\@new, \@modified, \@deleted);
        while (my $key = prompt('stage [y/n/d/l]?', 'yndl')) {
            last unless defined $key;
            if ($key eq 'd') {
                foreach my $file (@new) {
                    $current->git('diff', '/dev/null', $file);
                }
                $current->git('diff');
            } elsif ($key eq 'l') {
                list(\@new, \@modified, \@deleted);
            } else {
                if ($key eq 'y') {
                    $current->git('add', @new) if @new;
                    $current->git('add', @modified) if @modified;
                    $current->git('rm', @deleted) if @deleted;
                }
                last;
            }
        }
    }

    $current->fix()
        if $current->is_workdir;
}

sub list {
    my ($new, $modified, $deleted) = @_;
    list_files('new', $new);
    list_files('modified', $modified);
    list_files('deleted', $deleted);
}

sub list_files {
    my ($title, $files) = @_;
    return unless @$files;
    alert("$title file" . (scalar(@$files) == 1 ? '' : 's') . ":");
    foreach my $file (@$files) {
        warning($file);
    }
}

1;
