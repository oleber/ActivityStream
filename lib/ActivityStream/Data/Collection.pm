package ActivityStream::Data::Collection;

use Moose;
use MooseX::FollowPBP;

has 'collection' => (
    'is'       => 'ro',
    'isa'      => 'MongoDB::Collection',
    'required' => 1,
);

sub insert {
    my ( $self, $object, $options ) = @_;
    return $self->get_collection->insert( $object, { 'safe' => 1, %{ $options // {} } }, );
}

sub update {
    my ( $self, $criteria, $object, $options ) = @_;
    return $self->get_collection->update( $criteria, $object, { 'safe' => 1, %{ $options // {} } }, );
}

sub upsert {
    my ( $self, $criteria, $object, $options ) = @_;
    return $self->update( $criteria, $object, { 'upsert' => 1, %{ $options // {} } }, );
}

sub find_one {
    my ( $self, $criteria) = @_;
    return $self->get_collection->find_one( $criteria );
}

sub find {
    my ( $self, $criteria) = @_;
    return $self->get_collection->find( $criteria );
}

sub ensure_index {
    my ( $self, @params) = @_;
    return $self->get_collection->ensure_index( @params );
}


__PACKAGE__->meta->make_immutable;
no Moose;

1;
