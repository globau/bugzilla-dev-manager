package Bz::App::Command::info;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "shows information about the current instance";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my @info;
    my $current = Bz->current;
    if ($current->isa('Bz::Workdir')) {
        push @info, [ 'subdir',     coloured($current->dir, 'green') ];
        push @info, [ 'summary',    coloured($current->summary || '-', 'green') ];
        push @info, [ 'repo',       $current->repo ];
        push @info, [ 'bzr',        $current->bzr_location ];
        push @info, [ 'database',   $current->db ];
    } else {
        push @info, [ 'dir',        coloured($current->dir, 'green') ];
        push @info, [ 'location',   $current->bzr_location ];
    }

    my $template = '';
    my @values;
    foreach my $ra (@info) {
        $template .= "%8s: %s\n";
        push @values, @$ra;
    }
    printf $template, @values;
}

1;
