package ActivityStream::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use Readonly;
use Storable qw(dclone);

use ActivityStream::API::Activity::Friendship;
use ActivityStream::API::Activity::LinkShare;
use ActivityStream::X::ActivityNotFound;

Readonly my @ACTIVITY_PACKAGE_FOR => (
    [ qr/person:friendship:person/ => 'ActivityStream::API::Activity::Friendship' ],
    [ qr/person:share:link/        => 'ActivityStream::API::Activity::LinkShare' ],
);

Readonly my @OBJECT_PACKAGE_FOR => ( [ qr/person/ => 'ActivityStream::API::Object::Person' ], );

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

    foreach my $obj ( @{ $data->{'comments'} }, @{ $data->{'likers'} } ) {
        $obj->{'creator'} = $self->object_instance_from_rest_request_struct($obj->{'creator'});
    }

    return $pkg->from_rest_request_struct($data);
}

sub activity_instance_from_db {
    my ( $self, $criteria ) = @_;

    my $collection_activity = $self->get_environment->get_collection_factory->collection_activity;
    my $db_activity         = $collection_activity->find_one_activity($criteria);

    if ( defined $db_activity ) {
        my $pkg = $self->_activity_structure_class($db_activity);

        confess sprintf(
            "Class not found for %s on %s with mapping %s on %s",
            $self->_activity_type($db_activity), Dumper($db_activity),
            Dumper( [ $self->activity_package_for ] ), ref($self) ) if not defined $pkg;

        foreach my $obj ( @{ $db_activity->{'comments'} }, @{ $db_activity->{'likers'} } ) {
            $obj->{'creator'} = $self->object_instance_from_db($obj->{'creator'});
        }

        return $pkg->from_db_struct($db_activity);
    } else {
        die ActivityStream::X::ActivityNotFound->new;
    }
} ## end sub activity_instance_from_db

sub object_package_for {
    return @OBJECT_PACKAGE_FOR;
}

sub _object_type {
    my ( $self, $data ) = @_;

    if ( $data->{'object_id'} =~ /^(\w*):/ ) {
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

    return $pkg->from_rest_request_struct($data);
}

sub object_instance_from_db {
    my ( $self, $data ) = @_;

    my $pkg = $self->_object_structure_class($data);

    confess sprintf(
        "Class not found for %s on %s with mapping %s",
        $self->_object_type($data),
        Dumper($data), Dumper( [ $self->object_package_for ] ),
    ) if not defined $pkg;

    return $pkg->from_rest_request_struct($data);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
