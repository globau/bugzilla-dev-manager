package Bz::App::Command::memcached;
use parent 'Bz::App::Base';
use Bz;

use IO::Socket::INET;

use constant ALIASES => qw(
    memcache
);

sub usage_desc {
    return "bz memcached [host[:port]]";
}

sub abstract {
    return
        "toggles bugzilla's memcached parameter between disabled and the"
        . " supplied host/port (defaults to 127.0.0.1:11211).";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    if ($workdir->get_param('memcached_servers')) {
        $workdir->set_param('memcached_servers', '');
        return;
    }

    my ($host, $port) = ('127.0.0.1', 11211);
    if (@$args) {
        if ($args->[0] =~ /^([^:]+):(\d+)$/) {
            ($host, $port) = ($1, $2);
        } else {
            $host = $args->[0];
        }
    }

    my $sock = IO::Socket::INET->new(PeerAddr => $host, PeerPort => $port, Proto => 'tcp');
    if (!$sock) {
        return unless confirm("unable to connect to $host:$port.  continue?");
    }

    $workdir->set_param('memcached_servers', "$host:$port");
}

1;
