package Bz::Bugzilla;
use Bz;
use Moo;

use Bz::Bugzilla;
use JSON::XS qw(decode_json);
use LWP::UserAgent;
use MIME::Base64 qw(decode_base64);
use URI;
use URI::QueryParam;

use constant BUG_FIELDS => [qw(
    id
    product
    version
    target_milestone
    summary
    status
    resolution
    assigned_to
)];

has _ua        => ( is => 'lazy');
has _bug_cache => ( is => 'rw', default => sub { {} } );

sub _build__ua {
    return LWP::UserAgent->new( agent => 'bz-dev' );
}

sub bug {
    my ($self, $bug_id) = @_;
    die "missing id" unless $bug_id;

    if (!exists $self->_bug_cache->{$bug_id}) {
        my $response = $self->_get(
            'bug/' . $bug_id,
            {
                include_fields => BUG_FIELDS,
            }
        );
        $self->_bug_cache->{$bug_id} = $response->{bugs}->[0];
    }
    return $self->_bug_cache->{$bug_id};
}

sub bugs {
    my ($self, $bug_ids) = @_;
    die "missing ids" unless $bug_ids && @$bug_ids;

    my @fetch_ids;
    foreach my $bug_id (@$bug_ids) {
        push @fetch_ids, $bug_id unless exists $self->_bug_cache->{$bug_id};
    }

    if (@fetch_ids) {
        my $response = $self->_get(
            'bug/',
            {
                ids => \@fetch_ids,
                include_fields => BUG_FIELDS,
            }
        );
        foreach my $bug (@{ $response->{bugs} }) {
            $self->_bug_cache->{$bug->{id}} = $bug;
        }
    }

    my @response;
    foreach my $bug_id (@$bug_ids) {
        push @response, $self->_bug_cache->{$bug_id};
    }
    return \@response;
}

sub user {
    my ($self, $login) = @_;
    die "missing login" unless $login;

    my $response = $self->_get(
        'user',
        {
            names => [ $login ],
            include_fields => [ 'name', 'real_name' ],
        }
    )->{users};
    return unless $response && @$response;
    return {
        login   => $response->[0]->{name},
        name    => $response->[0]->{real_name},
    };
}

sub attachments {
    my ($self, $bug_id) = @_;
    die "missing bug_id" unless $bug_id;
    return $self->_get(
        "bug/$bug_id/attachment",
        {
            exclude_fields => [ 'data' ],
        }
    )->{bugs}->{$bug_id} // [];
}

sub attachment {
    my ($self, $attach_id) = @_;
    die "missing attach_id" unless $attach_id;
    my $attachments = $self->_get(
        "bug/attachment/$attach_id"
    );
    my $attachment = $attachments->{attachments}->{$attach_id}
        || die "failed to get attachment $attach_id information\n";
    if (exists $attachment->{data}) {
        $attachment->{data} = decode_base64($attachment->{data});
    }
    return $attachment;
}

sub _get {
    my ($self, $endpoint, $args) = @_;
    die "config file missing bmo_api_key\n" unless Bz->config->bmo_api_key;
    $args //= {};

    if (exists $args->{include_fields} && ref($args->{include_fields})) {
        $args->{include_fields} = join(',', @{ $args->{include_fields} });
    }

    my $uri = URI->new('https://bugzilla.mozilla.org/rest/' . $endpoint);
    foreach my $name (sort keys %$args) {
        $uri->query_param($name => $args->{$name});
    }

    my $request = HTTP::Request->new('GET', $uri->as_string);
    $request->header( Content_Type => 'application/json' );
    $request->header( Accept => 'application/json' );
    $request->header( X_Bugzilla_API_Key => Bz->config->bmo_api_key );

    my $response = $self->_ua->request($request);
    if ($response->code !~ /^2/) {
        my $error = $response->message;
        eval {
            $error = decode_json($response->decoded_content)->{message};
        };
        die $error . "\n";
    }
    return decode_json($response->decoded_content);
}

1;
