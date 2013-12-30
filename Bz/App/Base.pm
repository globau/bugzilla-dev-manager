package Bz::App::Base;
use Bz::App -command;
use Bz;

sub ALIASES { () }

sub command_names {
    my ($self) = @_;
    my @names = $self->SUPER::command_names();
    push @names, $self->ALIASES;
    foreach my $name (grep { /_/ } @names) {
        (my $alt = $name) =~ tr/_/-/;
        push @names, $alt;
    }
    return @names;
}

1;
