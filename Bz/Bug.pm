package Bz::Bug;
use Bz;
use Moo;

has id          => ( is => 'ro', required => 1 );
has summary     => ( is => 'lazy' );
has product     => ( is => 'lazy' );
has version     => ( is => 'lazy' );
has target      => ( is => 'lazy' );
has status      => ( is => 'lazy' );
has resolution  => ( is => 'lazy' );
has assignee    => ( is => 'lazy' );

has _bug        => ( is => 'lazy' );

sub _build_summary      { $_[0]->_bug->{summary} }
sub _build_product      { $_[0]->_bug->{product} }
sub _build_version      { $_[0]->_bug->{version} }
sub _build_target       { $_[0]->_bug->{target_milestone} }
sub _build_status       { $_[0]->_bug->{status} }
sub _build_resolution   { $_[0]->_bug->{resolution} }
sub _build_assignee     { $_[0]->_bug->{assigned_to} }

sub _build__bug {
    my ($self) = @_;
    return Bz->bugzilla->bug($self->id);
}

1;
