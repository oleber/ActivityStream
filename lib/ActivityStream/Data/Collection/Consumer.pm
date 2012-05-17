package ActivityStream::Data::Collection::Consumer;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;

#{
#    "consumer_id" : <CONSUMER_ID>,
#    "day"         : <EPOCH / SECONDS_IN_A_DAY>,
#    "sources"     : {
#        <SOURCE_ID> : {
#            "last_status" : <LAST_STATUS>,
#            "activity" : {
#                <ACTIVITY_ID>: <EPOCH>,
#                ...
#            }
#        },
#        ...
#    }
#}

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub upsert_consumer {
     my ( $self, $criteria, $object ) = @_;
     return $self->get_collection->upsert( $criteria, $object );
}

sub find_consumers {
     my ( $self, $criteria) = @_;

     return $self->get_collection->find( $criteria );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
