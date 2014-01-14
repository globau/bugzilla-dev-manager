package Bz::Bugzilla;
use Bz;
use Moo;

use Bz::Bugzilla;
use HTTP::Cookies;
use XMLRPC::Lite;

has _proxy          => ( is => 'lazy' );
has _cookiejar      => ( is => 'lazy' );
has _authenticated  => ( is => 'rw', builder => 1);

sub _build__proxy {
    my ($self) = @_;
    return XMLRPC::Lite->proxy(
        "https://bugzilla.mozilla.org/xmlrpc.cgi",
        'cookie_jar' => $self->_cookiejar,
    );
}

sub _build__cookiejar {
    return HTTP::Cookies->new(
        file        => Bz->config->prefs_path . '/cookie_jar.txt',
        autosave    => 1,
    );
}

sub _build__authenticated {
    my ($self) = @_;
    return $self->_is_authenticated();
}

sub bug {
    my ($self, $args) = @_;
    die "missing id" unless $args->{id};

    my $response = $self->_rpc(
        'Bug.get',
        {
            ids => [ $args->{id} ],
            include_fields => $args->{fields},
        }
    );
    return $response->{bugs}->[0];
}

sub attachments {
    my ($self, $bug_id) = @_;
    die "missing bug_id" unless $bug_id;
    return $self->_rpc(
        'Bug.attachments',
        {
            ids => [ $bug_id ],
            exclude_fields => [ 'data' ],
        }
    )->{bugs}->{$bug_id} // [];
}

sub attachment {
    my ($self, $attach_id) = @_;
    die "missing attach_id" unless $attach_id;
    my $attachments = $self->_rpc(
        'Bug.attachments',
        {
            attachment_ids => [ $attach_id ],
        }
    );
    return $attachments->{attachments}->{$attach_id}
        || die "failed to get attachment $attach_id information\n"

}

sub _rpc {
    my ($self, @args) = @_;

    if (!$self->_authenticated) {
        my $login = Bz->config->bugzilla_mozilla_org_login;
        info("password for $login on  bugzilla.mozilla.org required:");
        my $password = password("passsword:");
        $self->_call(
            'User.login',
            {
                login       => $login,
                password    => $password,
            }
        );
        die "authentication failed\n"
            unless $self->_is_authenticated();
        $self->_authenticated(1);
    }

    return $self->_call(@args);
}

sub _call {
    my ($self, @args) = @_;
    my $response = $self->_proxy->call(@args);
    if ($response->fault) {
        die $response->faultstring . "\n";
    }
    return $response->result;
}

sub _is_authenticated {
    my ($self) = @_;
    my $response = $self->_call(
        'User.valid_login',
        {
            login   => Bz->config->bugzilla_mozilla_org_login,
        }
    );
    return $response ? 1 : 0;
}

1;
