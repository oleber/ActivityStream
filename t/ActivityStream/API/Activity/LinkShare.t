use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;

Readonly my $PKG => 'ActivityStream::API::Activity::LinkShare';

use_ok($PKG);
isa_ok( $PKG => 'ActivityStream::API::Activity' );

is( $PKG->get_attribute_base_class('actor'),  'ActivityStream::API::Object::Person' );
is( $PKG->get_attribute_base_class('object'), 'ActivityStream::API::Object::Link' );

Readonly my $PERSON_ACTOR_ID => 'person:1';
Readonly my $LINK_OBJECT_ID  => 'link:2';

Readonly my %DATA => (
    'actor'  => { 'object_id' => $PERSON_ACTOR_ID },
    'verb'   => 'share',
    'object' => { 'object_id' => $LINK_OBJECT_ID },
);
Readonly my $RID => ActivityStream::Util::generate_id();

{
    my $activity = $PKG->from_rest_request_struct( \%DATA );

    is( $activity->get_type, 'person:share:link' );
    cmp_deeply(
        $activity->to_db_struct,
        {
            %DATA,
            'activity_id'   => ignore,
            'visibility'    => 1,
            'creation_time' => num( time, 2 ),
            'likers'        => {},
            'comments'      => [],
        },
    );
    cmp_deeply( $PKG->from_db_struct( $activity->to_db_struct ), $activity );
}

my $environment      = ActivityStream::Environment->new;
my $async_user_agent = $environment->get_async_user_agent;

my $actor_request = $async_user_agent->create_request_person( { 'object_id' => $PERSON_ACTOR_ID, 'rid' => $RID } );
my $activityect_request = $async_user_agent->create_request_link( { 'object_id' => $LINK_OBJECT_ID, 'rid' => $RID } );

{
    note('Test bad Creation');
    dies_ok { $PKG->from_rest_request_struct( { %DATA, 'actor'  => { 'object_id' => 'link:1' } } ) };
    dies_ok { $PKG->from_rest_request_struct( { %DATA, 'verb'   => 'friendship' } ) };
    dies_ok { $PKG->from_rest_request_struct( { %DATA, 'object' => { 'object_id' => 'person:1' } } ) };
}

{
    note('Test Attributs');
    ok( $PKG->is_likeable );
    ok( $PKG->is_commentable );
    ok( $PKG->is_recomendable );

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    cmp_deeply( [ $activity->get_sources ], [$PERSON_ACTOR_ID] );
}

{
    note('Store DB');

    my $activity = $PKG->from_rest_request_struct( \%DATA );
    $activity->save_in_db($environment);
    cmp_deeply(
        ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $activity->get_activity_id } )->to_db_struct,
        $activity->to_db_struct
    );
}

{
    note("Normal Load");

    my $activity = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Link->new( { 'object_id' => $LINK_OBJECT_ID } );

    $async_user_agent->put_response_to( $actor_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person a', 'rid' => $RID } ) );

    $async_user_agent->put_response_to( $activityect_request->as_string,
        $async_user_agent->create_test_response_link( { 'title' => 'my link title', 'rid' => $RID } ) );

    $activity->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    cmp_deeply(
        $activity->to_rest_response_struct,
        {
            'actor'         => $person_actor->to_rest_response_struct,
            'verb'          => 'share',
            'object'        => $person_object->to_rest_response_struct,
            'activity_id'   => ignore,
            'likers'        => {},
            'comments'      => [],
            'creation_time' => num( time, 2 ),
        },
    );
    cmp_deeply( [ $activity->get_sources ], [$PERSON_ACTOR_ID] );

    ok( $activity->has_fully_loaded_successfully );
}

{
    note("Can't Load Actor");

    my $activity = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Link->new( { 'object_id' => $LINK_OBJECT_ID } );

    $async_user_agent->put_response_to( $actor_request->as_string, HTTP::Response->new(400) );

    $async_user_agent->put_response_to( $activityect_request->as_string,
        $async_user_agent->create_test_response_link( { 'title' => 'my link title', 'rid' => $RID } ) );

    $activity->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    dies_ok { $activity->to_rest_response_struct };
    ok( not $activity->has_fully_loaded_successfully );
}

{
    note("Can't Load Object");

    my $activity = $PKG->from_rest_request_struct( \%DATA );

    my $person_actor = ActivityStream::API::Object::Person->new( { 'object_id' => $PERSON_ACTOR_ID } );
    my $person_object = ActivityStream::API::Object::Link->new( { 'object_id' => $LINK_OBJECT_ID } );

    $async_user_agent->put_response_to( $actor_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person a', 'rid' => $RID } ) );

    $async_user_agent->put_response_to( $activityect_request->as_string, HTTP::Response->new(400), );

    $activity->prepare_load( $environment, { 'rid' => $RID } );
    $person_actor->prepare_load( $environment, { 'rid' => $RID } );
    $person_object->prepare_load( $environment, { 'rid' => $RID } );

    $async_user_agent->load_all;

    dies_ok { $activity->to_rest_response_struct };
    ok( not $activity->has_fully_loaded_successfully );
}

done_testing;
