package ActivityStream::API::Activity::LinkShare;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Thing::Person;
use ActivityStream::API::Thing::Link;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^share$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Thing::Link' );

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

sub is_likeable     { return 1 }
sub is_commentable  { return 1 }
sub is_recommendable { return 1 }

1;
