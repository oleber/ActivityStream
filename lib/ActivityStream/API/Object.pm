package ActivityStream::API::Object;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;

has 'object_id' => (
    'is'       => 'rw',
    'isa'      => subtype( 'Str' => where sub {/^\w+:\w+$/} ),
    'required' => 1,
);

has 'loaded_successfully' => (
    'is'  => 'rw',
    'isa' => 'Maybe[Bool]',
);

sub to_struct {
    my ($self) = @_;
    return { 'object_id' => $self->get_object_id };
}

sub to_simulate_rest_struct {
    my ($self) = @_;
    return { 'object_id' => $self->get_object_id };
}

sub to_db_struct {
    my ($self) = @_;
    return $self->to_struct;
}

sub to_rest_response_struct {
    my ($self) = @_;

    confess sprintf( "Object '%s' didn't load correctly", $self->get_object_id ) if not $self->get_loaded_successfully;

    return $self->to_struct;
}

sub from_struct {
    my ( $pkg, $data ) = @_;
    return $pkg->new($data);
}

sub from_rest_request_struct {
    my ( $pkg, $data ) = @_;
    return $pkg->from_struct($data);
}

sub from_db_struct {
    my ( $pkg, $data ) = @_;
    return $pkg->from_struct($data);
}

sub from_rest_response_struct {
    my ( $pkg, $data ) = @_;
    return $pkg->from_struct($data);
}

sub get_type {
    my ($self) = @_;

    if ( $self->get_object_id =~ /^.*?:(\w*)/ ) {
        return $1;
    }
}

sub prepare_load {
    my ( $self, $environment, $args ) = @_;

    if ( not defined $self->get_loaded_successfully ) {
        $self->set_loaded_successfully(1);
    }

    return;
}

sub load {
    my ( $self, $environment, $args ) = @_;

    local $environment->{'async_user_agent'} = ActivityStream::AsyncUserAgent->new(
        ua    => $environment->get_async_user_agent->get_ua,
        cache => $environment->get_async_user_agent->get_cache
    );

    $self->prepare_load( $environment, $args );
    $environment->get_async_user_agent->load_all( sub { Mojo::IOLoop->stop } );

    return;
}

sub is_recommendable {0}

sub save_recommendation {
    my ( $self, $environment, $param ) = @_;

    confess( sprintf( q(Object %s isn't recommendable), $self->get_object_id ) ) if not $self->is_recommendable;

    my $activity = $environment->get_activity_factory->activity_instance_from_rest_request_struct( {
            actor  => $param->{'creator'},
            verb   => 'recommend',
            object => $self->to_db_struct,
    } );

    $activity->save_in_db($environment);

    return $activity;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
