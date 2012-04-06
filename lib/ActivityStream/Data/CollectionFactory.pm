package ActivityStream::Data::CollectionFactory;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;
use ActivityStream::Data::Collection::Activity;
use ActivityStream::Data::Collection::Consumer;
use ActivityStream::Data::Collection::Source;

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

sub collection_consumer {
    return ActivityStream::Data::Collection::Consumer->new( collection => shift->create_collection('consumer') );
}

sub collection_source {
    return ActivityStream::Data::Collection::Source->new( collection => shift->create_collection('source') );
}

1;
