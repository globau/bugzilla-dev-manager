package Bz::App::Command::info;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "shows information about the current instance";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    my @info;
    push @info, [ 'subdir',     coloured($workdir->dir, 'green') ];
    push @info, [ 'summary',    coloured($workdir->summary || '-', 'green') ];
    push @info, [ 'repo',       $workdir->repo ];
    push @info, [ 'bzr',        $workdir->bzr_location ];
    push @info, [ 'database',   $workdir->db ];

    my $template = '';
    my @values;
    foreach my $ra (@info) {
        $template .= "%8s: %s\n";
        push @values, @$ra;
    }
    printf $template, @values;
}

1;
