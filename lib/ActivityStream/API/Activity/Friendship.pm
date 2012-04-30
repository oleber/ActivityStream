package ActivityStream::API::Activity::Friendship;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use ActivityStream::API::Activity;
use ActivityStream::API::Object::Person;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^friendship$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Object::Person' );

sub is_likeable     { return 1 }
sub is_commentable  { return 1 }
sub is_recomendable { return 0 }

sub prepare_load {
    my ( $self, $environment, $args ) = @_;

    $self->SUPER::prepare_load( $environment, $args );
    $self->set_loaded_successfully(1);

    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
