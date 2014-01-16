package Bz::App::Command::revert;
use parent 'Bz::App::Base';
use Bz;

use File::Path qw(remove_tree);

sub abstract {
    return "reverts ALL changes made to an instance";
}

sub description {
    return <<EOF;
this command performs the same function as 'bzr revert' with additional steps
to delete an files and directories which are not part of the tree.  after
reverting, the tree is updated.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $workdir = Bz->current_workdir;
    info("revert instance " . $workdir->dir);
    $workdir->unfix();
    $workdir->bzr('revert');
    $workdir->delete_crud();

    my $in_unknown = 0;
    foreach my $line ($workdir->bzr('st')) {
        chomp $line;
        if ($line =~ /^unknown:/) {
            $in_unknown = 1;
            next;
        }
        next unless $in_unknown;
        last unless $line =~ /^\s+(.+)$/;
        my $file = $1;
        next if $file =~ /\.patch$/;
        message("deleting $file");
        if (-d $file) {
            remove_tree($file) or die $!;
        } else {
            unlink($file);
        }
    }

    message("updating tree");
    $workdir->bzr('up');
    $workdir->fix();
}

1;
