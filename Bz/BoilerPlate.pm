package Bz::BoilerPlate;
use Bz;
use Moo;

use File::Slurp;

sub exists {
    my ($self, $file) = @_;

    my $content = read_file($file);
    return
        $content =~ /The contents of this file are subject to/
        || $content =~ /is subject to the terms of the/;
}

1;
