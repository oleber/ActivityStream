package MiniApp::WEB::Default;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Data::Dumper;

use ActivityStream::Environment;

sub get_handler_user_chooser {
    my $c = shift;

    my $rid = $c->session('rid');

    my $environment = ActivityStream::Environment->new( controller => $c );

    if ( not( defined $rid ) or not( exists $environment->get_config->{'users'}->{$rid} ) ) {
        $rid = ( keys( %{ $environment->get_config->{'users'} } ) )[0];
    }

    my @users;

    while ( my ( $key, $value ) = each( %{ $environment->get_config->{'users'} } ) ) {
        my %data = ( 'id' => $key, 'name' => "$value->{'first_name'} $value->{'last_name'}" );
        $data{'selected'} = ( $key eq $rid );
        push( @users, \%data );
    }

    $c->stash( 'users' => \@users );
    $c->session( 'rid' => $rid );

    return $c->render('myapp/default/user_chooser');
} ## end sub get_handler_user_chooser

sub post_handler_user_choosed {
    my $c = shift;

    $c->session( 'rid' => $c->param('rid') );

    return $c->render_json( {} );
}

1;
