package ActivityStream::API::Activity::PersonRecommendPerson;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Object::Person;

extends 'ActivityStream::API::ActivityChild';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^recommend$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Object::Person' );

__PACKAGE__->meta->make_immutable;
no Moose;

1;
