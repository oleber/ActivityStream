use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::Environment;
use ActivityStream::Util;

use_ok 'ActivityStream';

Readonly my $RID => ActivityStream::Util::generate_id();

my $environment         = ActivityStream::Environment->new;
my $collection_activity = $environment->get_collection_factory->collection_activity;
my $async_user_agent    = $environment->get_async_user_agent;

my $user_creator_1_id = "x:person:" . ActivityStream::Util::generate_id();
my $user_creator_2_id = "x:person:" . ActivityStream::Util::generate_id();

my $user_1_request = $async_user_agent->create_request_person( { 'object_id' => $user_creator_1_id, 'rid' => $RID } );
my $user_2_request = $async_user_agent->create_request_person( { 'object_id' => $user_creator_2_id, 'rid' => $RID } );

$async_user_agent->set_response_to( $user_1_request->as_string,
    $async_user_agent->create_test_response_person( { 'first_name' => 'person 1', 'rid' => $RID } ) );

$async_user_agent->set_response_to( $user_2_request->as_string,
    $async_user_agent->create_test_response_person( { 'first_name' => 'person 2', 'rid' => $RID } ) );

my %friendship_activity = (
    'actor'  => { 'object_id' => $user_creator_1_id },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $user_creator_2_id },
);

my $json = Mojo::JSON->new;
my $t    = Test::Mojo->new('ActivityStream');

{
    $t->post_ok( "/rest/activitystream", $json->encode( \%friendship_activity ) )->status_is(200);
    cmp_deeply( $t->tx->res->json, { 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
    $friendship_activity{'activity_id'}   = $t->tx->res->json->{'activity_id'};
    $friendship_activity{'creation_time'} = $t->tx->res->json->{'creation_time'};
    cmp_deeply(
        $collection_activity->find_one_activity( { 'activity_id' => $friendship_activity{'activity_id'} } ),
        superhashof(
            ActivityStream::API::Activity::Friendship->from_rest_request_struct( \%friendship_activity )->to_db_struct
        ),
    );
}

{
    note("GET single activity: existing");
    $t->get_ok("/rest/activitystream/activity/$friendship_activity{'activity_id'}?rid=$RID")->status_is(200);

    my $db_activity
          = $collection_activity->find_one_activity( { 'activity_id' => $friendship_activity{'activity_id'} } );
    my $activity = ActivityStream::API::Activity::Friendship->from_db_struct($db_activity);
    $activity->load( $environment, { 'rid' => $RID } );

    cmp_deeply( $t->tx->res->json, $activity->to_rest_response_struct );
}

{
    note("GET single activity: not existing");
    $t->get_ok("/rest/activitystream/activity/not_existing?rid=$RID")->status_is(404)->json_content_is( {} );
}

done_testing();
