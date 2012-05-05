package ActivityStream::Data::Collection::Source;

use Moose;
use MooseX::FollowPBP;

use Data::Dumper;

use ActivityStream::Data::Collection;

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub upsert_source {
     my ( $self, $criteria, $object ) = @_;

     return $self->get_collection->upsert( $criteria, $object );
}

sub find_source {
     my ( $self, $criteria) = @_;

     return $self->get_collection->find( $criteria );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
