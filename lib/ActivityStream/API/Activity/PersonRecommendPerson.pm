package ActivityStream::API::Activity::PersonRecommendPerson;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Thing::Person;

extends 'ActivityStream::API::ActivityChild';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^recommend$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Thing::Person' );

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

1;
