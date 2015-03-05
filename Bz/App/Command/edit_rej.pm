package Bz::App::Command::edit_rej;
use parent 'Bz::App::Base';
use Bz;

use File::Find;
use IPC::System::Simple qw(runx);

use constant ALIASES => qw(
    edit_rejects
);

sub abstract {
    return "edit merge rejects and base files in order";
}

sub usage_desc {
    return "bz edit-rej";
}

sub description {
    return <<EOF;
after a merge conflict resulting in rejects:
  2 out of 2 hunks ignored -- saving rejects to file Bugzilla.pm.rej
edit-rej will edit Bugzilla.pm.rej and Bugzilla.pm
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;

    my $current = Bz->current;
    my @rej;
    find(sub {
        return unless -f $_ && /\.rej$/;
        push @rej, $File::Find::name;
        (my $file = $File::Find::name) =~ s/\.rej$//;
        push @rej, $file;
    }, $current->path);
    die "failed to find any .rej files\n" unless @rej;

    runx('vim', @rej);
}

1;
