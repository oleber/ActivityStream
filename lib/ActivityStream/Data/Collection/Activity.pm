package ActivityStream::Data::Collection::Activity;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub insert_activity {
     my ( $self, $object ) = @_;
     return $self->get_collection->insert( $object );
}

sub find_one_activity {
    my ( $self, $criteria) = @_;
    return $self->get_collection->find_one( $criteria );
}

1;
