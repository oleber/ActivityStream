package MiniApp::API::Activity::PersonRecommendFile;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Object::Person;
use MiniApp::API::Object::File;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'MiniApp::API::Object::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^recommend$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Object::File' );

sub is_likeable      { return 1 }
sub is_commentable   { return 1 }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
