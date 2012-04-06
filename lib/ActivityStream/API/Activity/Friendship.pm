package ActivityStream::API::Activity::Friendship;
use Moose;

use ActivityStream::API::Activity;
use ActivityStream::API::Object::Person;

extends 'ActivityStream::API::Activity';

has '+actor' => ( 'isa' => 'ActivityStream::API::Object::Person' );
has '+object' => ( 'isa' => 'ActivityStream::API::Object::Person' );

__PACKAGE__->meta->make_immutable;
no Moose;

1;
