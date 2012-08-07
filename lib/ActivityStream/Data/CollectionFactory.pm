package ActivityStream::Data::CollectionFactory;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;
use ActivityStream::Data::Collection::Activity;

has 'database' => (
    'is'  => 'ro',
    'isa' => 'MongoDB::Database',
);

sub create_collection {
    my ( $self, $name ) = @_;
    return ActivityStream::Data::Collection->new( collection => $self->get_database->get_collection($name) );
}

sub collection_activity {
    return ActivityStream::Data::Collection::Activity->new( collection => shift->create_collection('activity') );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
