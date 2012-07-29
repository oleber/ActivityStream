package ActivityStream::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use Readonly;
use Storable qw(dclone);

use ActivityStream::API::Activity::Friendship;
use ActivityStream::API::Activity::LinkShare;
use ActivityStream::API::Activity::PersonRecommendPerson;
use ActivityStream::API::Activity::PersonLikePerson;

use ActivityStream::X::ActivityNotFound;

Readonly my @ACTIVITY_PACKAGE_FOR => (
    [ qr/person:friendship:person/ => 'ActivityStream::API::Activity::Friendship' ],
    [ qr/person:share:link/        => 'ActivityStream::API::Activity::LinkShare' ],
    [ qr/person:recommend:person/  => 'ActivityStream::API::Activity::PersonRecommendPerson' ],
    [ qr/person:like:person/       => 'ActivityStream::API::Activity::PersonLikePerson' ],

);

Readonly my @OBJECT_PACKAGE_FOR => ( [ qr/person/ => 'ActivityStream::API::Thing::Person' ], );

has 'environment' => (
    'is'       => 'ro',
    'isa'      => 'ActivityStream::Environment',
    'weak_ref' => 1,
    'required' => 1,
);

sub activity_package_for {
    return @ACTIVITY_PACKAGE_FOR;
}

sub _activity_type {
    my ( $self, $data ) = @_;

    my @peaces = (
        $self->_object_type( $data->{'actor'} ),
        $data->{'verb'},
        $self->_object_type( $data->{'object'} ),
        ( defined( $data->{'target'} ) ? $self->_object_type( $data->{'target'} ) : () ),
    );

    return join( ':', @peaces );
}

sub _activity_structure_class {
    my ( $self, $data ) = @_;

    my $type = $self->_activity_type($data);

    foreach my $mapping ( $self->activity_package_for ) {
        return $mapping->[1] if $type =~ $mapping->[0];
    }

    return;
}

sub activity_instance_from_rest_request_struct {
    my ( $self, $data ) = @_;

    $data = dclone $data;

    my $pkg = $self->_activity_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_activity_type($data),
        Dumper($data), Dumper( [ $self->activity_package_for ] ),
    ) if not defined $pkg;

    if ( ( exists $data->{'super_parent_activity_id'} ) and ( not exists $data->{'super_parent_activity'} ) ) {
        $data->{'super_parent_activity'}
              = $self->activity_instance_from_db( { 'activity_id' => $data->{'super_parent_activity_id'} } );
    }

    foreach my $obj ( @{ $data->{'comments'} }, @{ $data->{'likers'} } ) {
        $obj->{'creator'} = $self->object_instance_from_rest_request_struct( $obj->{'creator'} );
    }

    return $pkg->from_rest_request_struct( $self->get_environment, $data );
} ## end sub activity_instance_from_rest_request_struct

sub activity_instance_from_db {
    my ( $self, $criteria ) = @_;

    my $collection_activity = $self->get_environment->get_collection_factory->collection_activity;
    my $data                = $collection_activity->find_one_activity($criteria);

    if ( defined $data ) {
        my $pkg = $self->_activity_structure_class($data);

        confess sprintf(
            "Class not found for %s on %s with mapping %s on %s",
            $self->_activity_type($data),
            Dumper($data), Dumper( [ $self->activity_package_for ] ),
            ref($self) ) if not defined $pkg;

        if ( ( exists $data->{'super_parent_activity_id'} ) and ( not exists $data->{'super_parent_activity'} ) ) {
            $data->{'super_parent_activity'}
                  = $self->activity_instance_from_db( { 'activity_id' => $data->{'super_parent_activity_id'} } );
        }

        foreach my $obj ( @{ $data->{'comments'} }, @{ $data->{'likers'} } ) {
            $obj->{'creator'} = $self->object_instance_from_db( $obj->{'creator'} );
        }

        return $pkg->from_db_struct( $self->get_environment, $data );
    } else {
        die ActivityStream::X::ActivityNotFound->new;
    }
} ## end sub activity_instance_from_db

sub activity_instance_from_rest_response_struct {
    my ( $self, $data ) = @_;

    $data = dclone $data;

    my $pkg = $self->_activity_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_activity_type($data),
        Dumper($data), Dumper( [ $self->activity_package_for ] ),
    ) if not defined $pkg;

    if ( defined $data->{'super_parent_activity'} ) {
        $data->{'super_parent_activity'}
              = $self->activity_instance_from_rest_response_struct( $data->{'super_parent_activity'} );
    }

    foreach my $obj ( @{ $data->{'comments'} }, @{ $data->{'likers'} } ) {
        $obj->{'creator'} = $self->object_instance_from_rest_response_struct( $obj->{'creator'} );
    }

    return $pkg->from_rest_response_struct( $self->get_environment, $data );
} ## end sub activity_instance_from_rest_response_struct

sub object_package_for {
    return @OBJECT_PACKAGE_FOR;
}

sub _object_type {
    my ( $self, $data ) = @_;

    if ( $data->{'object_id'} =~ /^.*:(\w*)/ ) {
        return $1;
    }

    confess "Can't parse object: $data->{'object_id'}";
}

sub _object_structure_class {
    my ( $self, $data ) = @_;

    my $type = $self->_object_type($data);

    foreach my $mapping ( $self->object_package_for ) {
        return $mapping->[1] if $type =~ $mapping->[0];
    }

    return;
}

sub object_instance_from_rest_request_struct {
    my ( $self, $data ) = @_;

    my $pkg = $self->_object_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_object_type($data),
        Dumper($data), Dumper( [ $self->object_package_for ] ),
    ) if not defined $pkg;

    return $pkg->from_rest_request_struct( $self->get_environment, $data );
}

sub object_instance_from_db {
    my ( $self, $data ) = @_;

    my $pkg = $self->_object_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_object_type($data),
        Dumper($data), Dumper( [ $self->object_package_for ] ),
    ) if not defined $pkg;

    return $pkg->from_db_struct( $self->get_environment, $data );
}

sub object_instance_from_rest_response_struct {
    my ( $self, $data ) = @_;

    my $pkg = $self->_object_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_object_type($data),
        Dumper($data), Dumper( [ $self->object_package_for ] ),
    ) if not defined $pkg;

    return $pkg->from_rest_response_struct( $self->get_environment, $data );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
