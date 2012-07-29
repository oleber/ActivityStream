package ActivityStream::API::Activity::PersonCommentPerson;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Thing::Person;

extends 'ActivityStream::API::ActivityChild';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^comment$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Thing::Person' );

__PACKAGE__->meta->make_immutable;
no Moose;

1;
