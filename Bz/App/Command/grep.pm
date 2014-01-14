package Bz::App::Command::grep;
use parent 'Bz::App::Base';
use Bz;

sub abstract {
    return "searches for instances by summary";
}

sub usage_desc {
    return "bz %o <query>";
}

sub opt_spec {
    return (
        [ "nameonly|n",  "print just the first instance's name" ],
    );
}

sub description {
    return <<EOF;
searches the summaries of each instance for <query>.

if multiple words are provided, only summaries matching all words will be
displayed.
EOF
}

sub execute {
    my ($self, $opt, $args) = @_;
    info("searching summaries for: " . join(' ', @$args)) unless $opt->nameonly;

    $args = [ map { quotemeta } @$args ];
    my $match = sub {
        my $hits = 0;
        foreach my $arg (@$args) {
            $hits++ if $_[0]->summary =~ /$arg/i;
        }
        return $hits == scalar(@$args);
    };

    foreach my $workdir (@{ Bz->config->workdirs }) {
        next unless $match->($workdir);
        if ($opt->nameonly) {
            print $workdir->dir, "\n";
            return;
        } else {
            message(sprintf("%s: %s", $workdir->dir, $workdir->summary));
        }
    }
}

1;
