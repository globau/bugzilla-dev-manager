package Bz::Util;
use Bz;
use Moo;

# XXX this probably needs to go elsewhere

use File::Slurp;

has _nothing => ( is => 'lazy' );

sub boiler_plate_exists {
    my ($self, $file) = @_;

    my $content = read_file($file);
    return
        $content =~ /The contents of this file are subject to/
        || $content =~ /is subject to the terms of the/;
}

1;
