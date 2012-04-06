package ActivityStream::Data::Collection::Consumer;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub upsert_consumer {
     my ( $self, $criteria, $object ) = @_;
     return $self->get_collection->upsert( $criteria, $object );
}

1;
