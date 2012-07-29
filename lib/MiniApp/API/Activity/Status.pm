package MiniApp::API::Activity::Status;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Thing::Person;
use MiniApp::API::Thing::StatusMessage;

extends 'ActivityStream::API::Activity';

has '+actor'  => ( 'isa' => 'MiniApp::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^share$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Thing::StatusMessage' );

sub is_commentable   {1}
sub is_likeable      {1}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
