package ActivityStream::API::ActivityLike;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;

use ActivityStream::API::Object::Person;
use ActivityStream::Util;

has 'like_id' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'default' => sub {ActivityStream::Util::generate_id},
);

has 'user_id' => (
    'is'  => 'rw',
    'isa' => subtype( 'Str' => where {/^person:\w+$/} ),
);

has 'user' => (
    'is'  => 'rw',
    'isa' => 'Maybe[ActivityStream::API::Object::Person]',
);

has 'creation_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub { time() },
);

no Moose::Util::TypeConstraints;

sub to_db_struct {
    my ($self) = @_;
    return {
        'like_id'       => $self->get_like_id,
        'user_id'       => $self->get_user_id,
        'creation_time' => $self->get_creation_time,
    };
}

sub to_rest_response_struct {
    my ($self) = @_;

    my %data = (
        'like_id'       => $self->get_like_id,
        'user_id'       => $self->get_user_id,
        'creation_time' => $self->get_creation_time,
    );

    my $user = $self->get_user;

    if ( defined $user ) {
        if ( $user->get_loaded_successfully ) {
            $data{'user'} = $self->get_user->to_rest_response_struct;
            $data{'load'} = 'SUCCESS';
        } else {
            $data{'load'} = 'FAIL_LOAD';
        }
    } else {
        $data{'load'} = 'NOT_REQUESTED';
    }

    return \%data;
} ## end sub to_rest_response_struct

sub prepare_load {
    my ( $self, $environment, $args ) = @_;
    $self->set_user(
        $environment->get_activity_factory->object_instance_from_rest_request_struct(
            { 'object_id' => $self->get_user_id }
        ),
    );
    $self->get_user->prepare_load( $environment, $args );

    return;
}

sub load {
    my ( $self, $environment, $args ) = @_;

    local $environment->{'async_user_agent'} = ActivityStream::AsyncUserAgent::MongoUserAgent->new(
        ua    => $environment->get_async_user_agent->get_ua,
        cache => $environment->get_async_user_agent->get_cache
    );

    $self->prepare_load( $environment, $args );
    $environment->get_async_user_agent->load_all( sub { Mojo::IOLoop->stop } );

    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
