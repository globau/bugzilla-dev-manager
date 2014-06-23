package Bz::App::Command::memcached;
use parent 'Bz::App::Base';
use Bz;

use constant ALIASES => qw(
    memcache
);

sub abstract {
    return "toggles bugzilla's memcached parameter between disabled and 127.0.0.1:11211";
}

sub execute {
    my ($self, $opt, $args) = @_;
    my $workdir = Bz->current_workdir;

    if ($workdir->get_param('memcached_servers')) {
        $workdir->set_param('memcached_servers', '');
    } else {
        $workdir->set_param('memcached_servers', '127.0.0.1:11211');
    }
}

1;
