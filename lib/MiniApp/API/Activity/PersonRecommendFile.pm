package MiniApp::API::Activity::PersonRecommendFile;
use Moose;
use Moose::Util::TypeConstraints;

use MiniApp::API::Thing::Person;
use MiniApp::API::Thing::File;

extends 'ActivityStream::API::ActivityChild';

has '+actor'  => ( 'isa' => 'MiniApp::API::Thing::Person' );
has '+verb'   => ( 'isa' => subtype( 'Str' => where sub {/^recommend$/} ) );
has '+object' => ( 'isa' => 'MiniApp::API::Thing::File' );

sub is_likeable      { return 1 }
sub is_commentable   { return 1 }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
