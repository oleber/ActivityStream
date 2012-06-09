package MiniApp::API::Activity::Status;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Object::Person;
use MiniApp::API::Object::StatusMessage;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'MiniApp::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^share$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Object::StatusMessage' );

sub is_likeable     { return 1 }
sub is_commentable  { return 1 }
sub is_recomendable { return 0 }

sub get_sources {
    my ($self) = @_;
    return ( $self->get_actor->get_object_id, $self->get_object->get_object_id );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
