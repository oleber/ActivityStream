package MiniApp::API::Activity::PersonShareLink;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Object::Person;
use MiniApp::API::Object::Link;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'MiniApp::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^share$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Object::Link' );

sub is_likeable      { return 1 }
sub is_commentable   { return 1 }
sub is_recommendable { return 1 }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
