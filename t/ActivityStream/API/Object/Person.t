#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;
use Storable qw(dclone);
use Try::Tiny;

use ActivityStream::Environment;
use ActivityStream::Util;

Readonly my $PKG => 'ActivityStream::API::Object::Person';

use_ok($PKG);
isa_ok( $PKG, 'ActivityStream::API::Object' );

Readonly my $PERSON_ID => sprintf( 'person:%s', ActivityStream::Util::generate_id );
Readonly my $RID => ActivityStream::Util::generate_id;

Readonly my %DATA => ( 'object_id' => $PERSON_ID );
Readonly my %DATA_REQUEST => ( %DATA, 'rid' => $RID );
Readonly my %DATA_RESPONSE => (
    %DATA,
    'first_name'  => 'João',
    'last_name'   => 'Vitor',
    'profile_url' => 'http://profile/joão_vitor',
    'large_image' => 'http://profile/joão_vitor/large_image',
    'small_image' => 'http://profile/joão_vitor/small_image',
    'company'     => 'PT AG',
);

my $request_as_string = $PKG->new( 'object_id' => $PERSON_ID )->create_request( \%DATA_REQUEST );

{
    note('Check object_id');
    throws_ok { $PKG->new( %DATA, 'object_id' => 'x:xpto:125' ) } qr/object_id/;
}

{
    note('Test DB');
    my $obj = $PKG->new(%DATA);
    is( $obj->get_type, 'person' );

    cmp_deeply( $obj->to_db_struct,                         \%DATA );
    cmp_deeply( $PKG->from_db_struct( $obj->to_db_struct ), $obj );
}

{
    note('Test Successfull response');

    my $t = Test::Mojo->new( Mojolicious->new );

    $t->app->routes->get($request_as_string)
          ->to( 'cb' => $PKG->create_test_response( +{ %DATA_RESPONSE, 'rid' => $RID } ) );

    $t->app->routes->get('/test/data')->to(
        'cb' => sub {
            my ($c) = @_;

            my $environment = ActivityStream::Environment->new( controller => $c );

            my $person = $PKG->new(%DATA);
            $person->prepare_load( $environment, { 'rid' => $RID } );

            $environment->get_async_user_agent->load_all(
                sub {
                    ok( $person->get_loaded_successfully );
                    $c->render_json( $person->to_rest_response_struct );
                },
            );
        },
    );

    $t->get_ok('/test/data')->json_content_is( \%DATA_RESPONSE );
}

{
    note('Test not Successfull response');

    my $t = Test::Mojo->new( Mojolicious->new );

    $t->app->routes->get($request_as_string)->to( 'cb' => sub { shift->render_json( {}, status => 400 ) } );

    $t->app->routes->get('/test/data')->to(
        'cb' => sub {
            my ($c) = @_;

            my $environment = ActivityStream::Environment->new( controller => $c );

            my $person = $PKG->new(%DATA);
            $person->prepare_load( $environment, { 'rid' => $RID } );

            $environment->get_async_user_agent->load_all(
                sub {
                    ok( not $person->get_loaded_successfully );
                    try { $c->render_json( $person->to_rest_response_struct ) } catch { $c->render_json( ['error'] ) };
                },
            );
        },
    );

    $t->get_ok('/test/data')->json_content_is( ['error'] );
}

{
    my $person = $PKG->new(%DATA);

    my $t = Test::Mojo->new( Mojolicious->new );

    $t->app->routes->get($request_as_string)
          ->to( 'cb' => sub { $PKG->create_test_response( +{ %DATA_RESPONSE, 'rid' => $RID } )->(shift); }, );

    my $environment = ActivityStream::Environment->new( ua => $t->ua );

    $person->load( $environment, { 'rid' => $RID } );

    cmp_deeply( $person->to_rest_response_struct, \%DATA_RESPONSE );
}

done_testing;
