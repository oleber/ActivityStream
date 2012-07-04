#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;

Readonly my $PKG => 'ActivityStream::API::Activity::Friendship';

use_ok($PKG);
isa_ok( $PKG => 'ActivityStream::API::Activity' );

is( $PKG->get_attribute_base_class('actor'),  'ActivityStream::API::Object::Person' );
is( $PKG->get_attribute_base_class('object'), 'ActivityStream::API::Object::Person' );

Readonly my $PERSON_ACTOR_ID  => '1:person';
Readonly my $PERSON_OBJECT_ID => '2:person';

Readonly my %DATA => (
    'actor'  => { 'object_id' => $PERSON_ACTOR_ID },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $PERSON_OBJECT_ID },
);
Readonly my $RID => ActivityStream::Util::generate_id();

{
    my $activity = $PKG->from_rest_request_struct( \%DATA );

    is( $activity->get_type, 'person:friendship:person' );
    cmp_deeply(
        $activity->to_db_struct,
        {
            %DATA,
            'activity_id'   => ignore,
            'visibility'    => 1,
            'creation_time' => num( time, 2 ),
            'timebox'       => ignore,
            'likers'        => [],
            'comments'      => [],
        },
    );
    cmp_deeply( $PKG->from_db_struct( $activity->to_db_struct ), $activity );
}

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );
my $async_user_agent = $environment->get_async_user_agent;

my $actor = ActivityStream::API::Object::Person->new( 'object_id' => $PERSON_ACTOR_ID );
$t->app->routes->get( $actor->create_request( $environment, { 'rid' => $RID } ) )
      ->to( 'cb' => $actor->create_test_response( { 'rid' => $RID } ) );

my $object = ActivityStream::API::Object::Person->new( 'object_id' => $PERSON_OBJECT_ID );
$t->app->routes->get( $object->create_request( $environment, { 'rid' => $RID } ) )
      ->to( 'cb' => $object->create_test_response( { 'rid' => $RID } ) );

{
    note('Test bad Creation');
    dies_ok { $PKG->from_rest_request_struct( +{ %DATA, 'actor'  => { 'object_id' => 'link:1' } } ) };
    dies_ok { $PKG->from_rest_request_struct( +{ %DATA, 'verb'   => 'share' } ) };
    dies_ok { $PKG->from_rest_request_struct( +{ %DATA, 'object' => { 'object_id' => 'link:1' } } ) };
}

{
    note('Test Attributs');
    ok( $PKG->is_likeable );
    ok( $PKG->is_commentable );
    ok( not $PKG->is_recommendable );

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    cmp_deeply( [ $activity->get_sources ], [ $PERSON_ACTOR_ID, $PERSON_OBJECT_ID ] );
}

{
    note('Store DB');

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    $activity->save_in_db($environment);
    cmp_deeply(
        $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity->get_activity_id } )
              ->to_db_struct,
        $activity->to_db_struct
    );
}

{
    note("Normal Load");

    my $person_actor = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    $person_actor->load( $environment, { 'rid' => $RID } );

    my $person_object = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_OBJECT_ID } );
    $person_object->load( $environment, { 'rid' => $RID } );

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    $activity->load( $environment, { 'rid' => $RID } );

    cmp_deeply(
        $activity->to_rest_response_struct,
        {
            'actor'         => $person_actor->to_rest_response_struct,
            'verb'          => 'friendship',
            'object'        => $person_object->to_rest_response_struct,
            'activity_id'   => ignore,
            'likers'        => [],
            'comments'      => [],
            'creation_time' => num( time, 2 ),
        },
    );

    ok( $activity->has_fully_loaded_successfully );
}

{
    note("Can't Load Actor");

    local $async_user_agent->{'cache'}{ "GET " . $actor->create_request( $environment, { 'rid' => $RID } ) }
          = Mojo::Transaction::HTTP->new( res => Mojo::Message::Response->new( code => 400 ) );

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    $activity->load( $environment, { 'rid' => $RID } );

    dies_ok { $activity->to_rest_response_struct };
    ok( not $activity->has_fully_loaded_successfully );
}

{
    note("Can't Load Object");

    local $async_user_agent->{'cache'}{ "GET " . $object->create_request( $environment, { 'rid' => $RID } ) }
          = Mojo::Transaction::HTTP->new( res => Mojo::Message::Response->new( code => 400 ) );

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    $activity->load( $environment, { 'rid' => $RID } );

    dies_ok { $activity->to_rest_response_struct };
    ok( not $activity->has_fully_loaded_successfully );
}

done_testing;
