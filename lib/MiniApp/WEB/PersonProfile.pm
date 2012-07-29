package MiniApp::WEB::PersonProfile;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Data::Dumper;

use MiniApp::API::Object::Person;

sub get_handler {
    my ($c) = @_;

    my $rid       = $c->session('rid');
    my $person_id = $c->param('person_id');

    my $environment = ActivityStream::Environment->new( controller => $c );

    my $person = MiniApp::API::Object::Person->new( 'object_id' => $person_id );
    $person->prepare_load( { rid => $rid } );

    $environment->get_async_user_agent->load_all(
        sub {
            if ( $person->get_loaded_successfully ) {
                $c->stash( 'person' => $person );
                $c->render('myapp/person_profile');
            } else {
                $c->render( 'text' => "user not found", status => 404 );
            }
        } );

    return;
} ## end sub get_handler

1;
