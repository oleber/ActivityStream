use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::Environment;

Readonly my $PKG => 'ActivityStream::API::Activity::Friendship';

use_ok($PKG);
isa_ok( $PKG => 'ActivityStream::API::Activity' );

is( $PKG->get_attribute_base_class('actor'),  'ActivityStream::API::Object::Person' );
is( $PKG->get_attribute_base_class('object'), 'ActivityStream::API::Object::Person' );

Readonly my $PERSON_ACTOR_ID  => 'x:person:1';
Readonly my $PERSON_OBJECT_ID => 'x:person:2';

Readonly my %DATA => (
    'actor'  => { 'object_id' => $PERSON_ACTOR_ID },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $PERSON_OBJECT_ID },
);
Readonly my $RID => ActivityStream::Util::generate_id();

{
    my $obj = $PKG->from_rest_request_struct( \%DATA );

    is( $obj->get_type, 'person:friendship:person' );
    cmp_deeply( $obj->to_db_struct, { %DATA, 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
    cmp_deeply( $PKG->from_db_struct( $obj->to_db_struct ), $obj );
}

my $environment      = ActivityStream::Environment->new;
my $async_user_agent = $environment->get_async_user_agent;

my $actor_request  = $async_user_agent->create_request_person( { 'object_id' => $PERSON_ACTOR_ID,  'rid' => $RID } );
my $object_request = $async_user_agent->create_request_person( { 'object_id' => $PERSON_OBJECT_ID, 'rid' => $RID } );

{
    note("Normal Load");

    my $obj = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor  = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_OBJECT_ID } );

    $async_user_agent->set_response_to( $actor_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person a', 'rid' => $RID } ) );

    $async_user_agent->set_response_to( $object_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person b', 'rid' => $RID } ) );

    $obj->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    cmp_deeply(
        $obj->to_rest_response_struct,
        {
            'actor'         => $person_actor->to_rest_response_struct,
            'verb'          => 'friendship',
            'object'        => $person_object->to_rest_response_struct,
            'activity_id'   => ignore,
            'creation_time' => num( time, 2 ),
        },
    );
    cmp_deeply( [ $obj->get_sources ], [$PERSON_ACTOR_ID] );

    ok( $obj->has_fully_loaded_successfully );
}

{
    note("Can't Load Actor");

    my $obj = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor  = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_OBJECT_ID } );

    $async_user_agent->set_response_to( $actor_request->as_string, HTTP::Response->new(400) );

    $async_user_agent->set_response_to( $object_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person b', 'rid' => $RID } ) );

    $obj->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    dies_ok { $obj->to_rest_response_struct };
    ok( not $obj->has_fully_loaded_successfully );
}

{
    note("Can't Load Object");

    my $obj = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor  = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_OBJECT_ID } );

    $async_user_agent->set_response_to( $actor_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person a', 'rid' => $RID } ) );

    $async_user_agent->set_response_to( $object_request->as_string, HTTP::Response->new(400), );

    $obj->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    dies_ok { $obj->to_rest_response_struct };
    ok( not $obj->has_fully_loaded_successfully );
}

done_testing;
