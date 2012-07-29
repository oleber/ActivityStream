package ActivityStream::API::Thing;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;

use ActivityStream::Environment;

has 'object_id' => (
    'is'       => 'rw',
    'isa'      => subtype( 'Str' => where sub {/^\w+:\w+$/} ),
    'required' => 1,
);

has 'loaded_successfully' => (
    'is'  => 'rw',
    'isa' => 'Maybe[Bool]',
);

has 'environment' => (
    'is'       => 'ro',
    'isa'      => 'ActivityStream::Environment',
    'weak_ref' => 1,
    'required' => 1,
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
    my ( $pkg, $environment, $data ) = @_;
    return $pkg->new({'environment' => $environment, %$data});
}

sub from_rest_request_struct {
    my ( $pkg, $environment, $data ) = @_;
    return $pkg->from_struct($environment, $data);
}

sub from_db_struct {
    my ( $pkg, $environment, $data ) = @_;
    return $pkg->from_struct($environment, $data);
}

sub from_rest_response_struct {
    my ( $pkg, $environment, $data ) = @_;
    return $pkg->from_struct($environment, $data);
}

sub get_type {
    my ($self) = @_;

    if ( $self->get_object_id =~ /^.*?:(\w*)/ ) {
        return $1;
    }
}

sub prepare_load {
    my ( $self, $args ) = @_;

    if ( not defined $self->get_loaded_successfully ) {
        $self->set_loaded_successfully(1);
    }

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

sub is_likeable    { 0 }
sub is_commentable { 0 }
sub is_recommendable {0}

sub save_recommendation {
    my ( $self, $parent_activity, $param ) = @_;

    confess( sprintf( q(Object %s isn't recommendable), $self->get_object_id ) ) if not $self->is_recommendable;

    my %data = (
        'actor'              => $param->{'creator'},
        'verb'               => 'recommend',
        'object'             => $self->to_simulate_rest_struct,
        'parent_activity_id' => $parent_activity->get_activity_id,
    );

    $data{'super_parent_activity_id'}
          = $parent_activity->can('get_super_parent_activity_id')
          ? $parent_activity->get_super_parent_activity_id
          : $parent_activity->get_activity_id;

    return $self->get_environment->get_activity_factory->activity_instance_from_rest_request_struct( \%data )
          ->save_in_db;
} ## end sub save_recommendation

sub save_liker {
    my ( $self, $parent_activity, $param ) = @_;

    confess( sprintf( q(Object %s isn't likeable), $self->get_object_id ) ) if not $self->is_likeable;

    my %data = (
        'actor'              => $param->{'creator'},
        'verb'               => 'like',
        'object'             => $self->to_simulate_rest_struct,
        'parent_activity_id' => $parent_activity->get_activity_id,
    );

    $data{'super_parent_activity_id'}
          = $parent_activity->can('get_super_parent_activity_id')
          ? $parent_activity->get_super_parent_activity_id
          : $parent_activity->get_activity_id;

    return $self->get_environment->get_activity_factory->activity_instance_from_rest_request_struct( \%data )
          ->save_in_db;
} ## end sub save_recommendation

sub save_comment {
    my ( $self, $parent_activity, $param ) = @_;

    confess( sprintf( q(Object %s isn't commentable), $self->get_object_id ) ) if not $self->is_commentable;

    my %data = (
        'actor'              => $param->{'creator'},
        'verb'               => 'comment',
        'object'             => $self->to_simulate_rest_struct,
        'parent_activity_id' => $parent_activity->get_activity_id,
    );

    $data{'super_parent_activity_id'}
          = $parent_activity->can('get_super_parent_activity_id')
          ? $parent_activity->get_super_parent_activity_id
          : $parent_activity->get_activity_id;

    return $self->get_environment->get_activity_factory->activity_instance_from_rest_request_struct( \%data )
          ->save_in_db;
} ## end sub save_recommendation

__PACKAGE__->meta->make_immutable;
no Moose;

1;
