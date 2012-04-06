package ActivityStream::API::Activity;
use Moose;
use MooseX::FollowPBP;

use Data::Dumper;

use ActivityStream::API::Object;
use ActivityStream::Util;

has 'activity_id' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'default' => sub { ActivityStream::Util::generate_id() },
);

has 'creation_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub { time() },
);

has 'actor' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Object',
    'required' => 1,
);

has 'verb' => (
    'is'       => 'rw',
    'isa'      => 'Str',
    'required' => 1,
);

has 'object' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Object',
    'required' => 1,
);

has 'target' => (
    'is'  => 'rw',
    'isa' => 'Maybe[ActivityStream::API::Object]'
);

sub to_db_struct {
    my ($self) = @_;
    my %data = (
        'activity_id'   => $self->get_activity_id,
        'actor'         => $self->get_actor->to_db_struct,
        'verb'          => $self->get_verb,
        'object'        => $self->get_object->to_db_struct,
        'creation_time' => $self->get_creation_time,
    );

    if ( defined $self->get_target ) {
        $data{'target'} = $self->get_target->to_db_struct;
    }

    return \%data;
}

sub to_rest_response_struct {
    my ($self) = @_;

    my %data = (
        'activity_id'   => $self->get_activity_id,
        'actor'         => $self->get_actor->to_rest_response_struct,
        'verb'          => $self->get_verb,
        'object'        => $self->get_object->to_rest_response_struct,
        'creation_time' => $self->get_creation_time,
    );

    if ( defined $self->get_target ) {
        $data{'target'} = $self->get_target->to_rest_response_struct;
    }

    return \%data;
}

sub get_sources {
    my ($self) = @_;
    return ( $self->get_actor->get_object_id );
}

sub get_type {
    my ($self) = @_;
    return join( ':',
        $self->get_actor->get_type,
        $self->get_verb,
        $self->get_object->get_type,
        ( $self->get_target ? $self->get_target->get_type : () ),
    );
}

sub from_db_struct {
    my ( $pkg, $data ) = @_;

    my %data = %$data;

    $data{'actor'}  = $pkg->get_attribute_base_class('actor')->from_db_struct( $data{'actor'} );
    $data{'object'} = $pkg->get_attribute_base_class('object')->from_db_struct( $data{'object'} );

    if ( defined $data{'target'} ) {
        $data{'target'} = $pkg->get_attribute_base_class('target')->from_db_struct( $data{'target'} );
    }

    return $pkg->new(%data);
}

sub from_rest_request_struct {
    my ( $pkg, $data ) = @_;

    my %data = %$data;

    $data{'actor'}  = $pkg->get_attribute_base_class('actor')->from_rest_request_struct( $data{'actor'} );
    $data{'object'} = $pkg->get_attribute_base_class('object')->from_rest_request_struct( $data{'object'} );

    if ( defined $data{'target'} ) {
        $data{'target'} = $pkg->get_attribute_base_class('target')->from_rest_request_struct( $data{'target'} );
    }

    return $pkg->new(%data);
}

sub get_attribute_base_class {
    my ( $pkg, $name ) = @_;

    my $type_constraint = $pkg->meta->find_attribute_by_name($name)->type_constraint;

    if ( $type_constraint->isa('Moose::Meta::TypeConstraint::Parameterized') ) {
        $type_constraint = $type_constraint->type_parameter;
    }

    return $type_constraint->name;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
