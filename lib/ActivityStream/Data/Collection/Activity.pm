package ActivityStream::Data::Collection::Activity;

use Moose;
use MooseX::FollowPBP;

use ActivityStream::Data::Collection;

#{
#    "activity_id" : <ACTIVITY_ID>,
#    "actor" : {
#        "object_id" : <OBJECT_ID>
#    }
#    "verb"        : <VERB>,
#    "object"      : {
#        "object_id" : <OBJECT_ID>
#    },
#    "target"      : {
#        "object_id" : <OBJECT_ID>
#    },
#    "visibility"  : <BOOLEAN>,
#    "likers"      : [
#        {
#            "like_id"       : <LIKE_ID>,
#            "user_id"       : <USER_ID>,
#            "creation_time" : <CREATION TIME IN EPOC>
#        },
#        ...
#    ],
#    "comments"    : [
#        {
#            "comment_id"    : <LIKE_ID>,
#            "user_id"       : <USER_ID>,
#            "body"          : <BODY>,
#            "creation_time" : <CREATION TIME IN EPOC>
#        },
#        ...
#    ],
#    "creation_time" : <CREATION TIME IN EPOC>
#}

has 'collection' => ( is => 'rw', isa => 'ActivityStream::Data::Collection', 'required' => 1 );

sub insert_activity {
    my ( $self, $object ) = @_;
    return $self->get_collection->insert($object);
}

sub update_activity {
    my ( $self, $criteria, $object ) = @_;
    return $self->get_collection->update( $criteria, $object );
}

sub upsert_activity {
    my ( $self, $criteria, $object ) = @_;
    return $self->get_collection->upsert( $criteria, $object );
}

sub find_one_activity {
    my ( $self, $criteria ) = @_;
    return $self->get_collection->find_one($criteria);
}

sub find_activities {
    my ( $self, $criteria ) = @_;

    return $self->get_collection->find($criteria);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
