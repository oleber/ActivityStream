package MiniApp::API::Activity::PersonLikeLink;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Thing::Person;
use MiniApp::API::Thing::Link;

extends 'ActivityStream::API::ActivityChild';

has '+actor'  => ( 'isa' => 'MiniApp::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^like$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Thing::Link' );

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

sub is_commentable { return 1 }
sub is_likeable    { return 1 }

1;
