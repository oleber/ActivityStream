package MiniApp::WEB::PersonProfile;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Data::Dumper;

use MiniApp::API::Object::Person;

sub get_handler {
    my ($c) = @_;

    my $rid = $c->session('rid');
    my $person_id = $c->param('person_id');

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;
warn '>>> ';
    my $person = MiniApp::API::Object::Person->new( 'object_id' => $person_id );
    $person->prepare_load( $environment, { rid => $rid } );
warn '>>> ';
    $async_user_agent->load_all( sub {
warn '>>> ';
        if ( $person->get_loaded_successfully ) {
warn '>>> ';
            $c->stash( 'person' => $person );
            $c->render('myapp/person_profile');
        } else {
warn '>>> ';
            $c->render('text' => "user not found", status => 404);
        }
    } );
warn '>>> ';
    return;
} ## end sub get_handler_activitystream

1;
