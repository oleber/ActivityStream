package ActivityStream::API::Object::Person;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;
use v5.10.1;

use Carp;

extends 'ActivityStream::API::Object';

has '+object_id' => ( isa => subtype( 'Str' => where {/^\w+:person:\w+$/} ) );

__PACKAGE__->meta->make_immutable;
no Moose;

1;
