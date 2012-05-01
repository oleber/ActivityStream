package ActivityStream::Data::Collection::Source;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub upsert_source {
     my ( $self, $criteria, $object ) = @_;
     return $self->get_collection->upsert( $criteria, $object );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
