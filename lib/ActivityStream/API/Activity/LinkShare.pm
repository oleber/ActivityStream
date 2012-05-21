package ActivityStream::API::Activity::LinkShare;
use Moose;
use Moose::Util::TypeConstraints;

use ActivityStream::API::Object::Person;
use ActivityStream::API::Object::Link;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'ActivityStream::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^share$/} ) );
has '+object' => ( 'isa' => 'ActivityStream::API::Object::Link' );

sub is_likeable     { return 1 }
sub is_commentable  { return 1 }
sub is_recomendable { return 1 }

sub prepare_load {
    my ( $self, $environment, $args ) = @_;

    $self->SUPER::prepare_load( $environment, $args );
    $self->set_loaded_successfully(1);

    return;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
