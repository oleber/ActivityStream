package ActivityStream::API::ActivityLike;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Mojo::IOLoop;

use ActivityStream::API::Thing::Person;
use ActivityStream::Util;

has 'like_id' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'default' => sub {ActivityStream::Util::generate_id},
);

has 'creator' => (
    'is'  => 'rw',
    'isa' => 'ActivityStream::API::Thing',
);

has 'creation_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub { time() },
);


has '_load_requested' => (
    'is'      => 'rw',
    'isa'     => 'Bool',
    'default' => sub {0},
);

has 'environment' => (
    'is'       => 'ro',
    'isa'      => 'ActivityStream::Environment',
    'weak_ref' => 1,
    'required' => 1,
);

no Moose::Util::TypeConstraints;

sub to_db_struct {
    my ($self) = @_;
    return {
        'like_id'       => $self->get_like_id,
        'creator'       => $self->get_creator->to_db_struct,
        'creation_time' => $self->get_creation_time,
    };
}

sub to_rest_response_struct {
    my ($self) = @_;

    my %data = (
        'like_id'       => $self->get_like_id,
        'creation_time' => $self->get_creation_time,
    );

    my $creator = $self->get_creator;

    if ( $self->_get_load_requested ) {
        if ( $creator->get_loaded_successfully ) {
            $data{'creator'} = $creator->to_rest_response_struct;
            $data{'load'}    = 'SUCCESS';
        } else {
            $data{'load'} = 'FAIL_LOAD';
        }
    } else {
        $data{'load'} = 'NOT_REQUESTED';
    }

    return \%data;
} ## end sub to_rest_response_struct

sub prepare_load {
    my ( $self, $args ) = @_;

    $self->_set_load_requested(1);
    $self->get_creator->prepare_load( $args );

    return;
}

sub load {
    my ( $self, $args ) = @_;

    local $self->get_environment->{'async_user_agent'} = ActivityStream::AsyncUserAgent->new(
        ua    => $self->get_environment->get_async_user_agent->get_ua,
        cache => $self->get_environment->get_async_user_agent->get_cache
    );

    $self->prepare_load( $args );
    $self->get_environment->get_async_user_agent->load_all( sub { Mojo::IOLoop->stop } );

    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
