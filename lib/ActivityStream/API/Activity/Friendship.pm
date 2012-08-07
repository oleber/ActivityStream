package ActivityStream::API::Activity::Friendship;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Thing::Person;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^friendship$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Thing::Person' );

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

sub is_likeable     { return 1 }
sub is_commentable  { return 1 }
sub is_recommendable { return 0 }

sub get_sources {
    my ($self) = @_;
    return ( $self->get_actor->get_object_id, $self->get_object->get_object_id );
}

1;
