use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use HTTP::Status qw(:constants);
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
my $user_creator_3_id = "x:person:" . ActivityStream::Util::generate_id();
my $user_creator_4_id = "x:person:" . ActivityStream::Util::generate_id();

my $user_1_request = $async_user_agent->create_request_person( { 'object_id' => $user_creator_1_id, 'rid' => $RID } );
my $user_2_request = $async_user_agent->create_request_person( { 'object_id' => $user_creator_2_id, 'rid' => $RID } );

$async_user_agent->put_response_to( $user_1_request->as_string,
    $async_user_agent->create_test_response_person( { 'first_name' => 'person 1', 'rid' => $RID } ) );

$async_user_agent->put_response_to( $user_2_request->as_string,
    $async_user_agent->create_test_response_person( { 'first_name' => 'person 2', 'rid' => $RID } ) );

my %friendship_activity = (
    'actor'  => { 'object_id' => $user_creator_1_id },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $user_creator_2_id },
);

my $json = Mojo::JSON->new;
my $t    = Test::Mojo->new('ActivityStream');

{
    $t->post_ok( "/rest/activitystream/activity", $json->encode( \%friendship_activity ) )->status_is(200);
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
    $t->get_ok("/rest/activitystream/activity/NotExisting?rid=$RID")->status_is(404)
          ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );
}

{
    my %expected_likes;

    {
        note("POST User Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(200);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        $expected_likes{$user_creator_3_id} = ActivityStream::API::ActivityLike->new(
            'like_id'       => $t->tx->res->json->{'like_id'},
            'user_id'       => $user_creator_3_id,
            'creation_time' => $t->tx->res->json->{'creation_time'},
        );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("POST Second Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_4_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(200);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        $expected_likes{$user_creator_4_id} = ActivityStream::API::ActivityLike->new(
            'like_id'       => $t->tx->res->json->{'like_id'},
            'user_id'       => $user_creator_4_id,
            'creation_time' => $t->tx->res->json->{'creation_time'},
        );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("POST User Like Not Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/like/activity/NotExisting",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(404)
              ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );
    }

    {
        note("DELETE First Like Existing activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                $expected_likes{$user_creator_4_id}->get_like_id, 'internal',
            ) )->status_is(200)->json_content_is( {} );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        delete $expected_likes{$user_creator_4_id};

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("DELETE Not Existing Like in activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                'NotExisting', 'internal'
            ),
        )->status_is(404)->json_content_is( { 'error' => 'LIKE_NOT_FOUND' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("DELETE Like on not existing activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                'NotExisting', $expected_likes{$user_creator_3_id}->get_like_id, 'internal'
            ),
        )->status_is(404)->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'}, $expected_likes{$user_creator_3_id}->get_like_id,
                $user_creator_4_id
            ) )->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'BAD_RID' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db(
            $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("DELETE Like on existing activity but without rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s',
                $friendship_activity{'activity_id'},
                $expected_likes{$user_creator_3_id}->get_like_id
            ),
            $json->encode( {} ) )->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'NO_RID_DEFINED' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'}, $expected_likes{$user_creator_3_id}->get_like_id,
                $user_creator_3_id
            ),
            $json->encode( { 'rid' => $user_creator_3_id } ) )->status_is(HTTP_OK)->json_content_is( {} );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        delete $expected_likes{$user_creator_3_id};

        cmp_deeply( $activity->get_likers, \%expected_likes );
    }

}

{
    note("POST User Comment Existing activity");

    Readonly my $BODY => ActivityStream::Util::generate_id;

    $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/comment/activity/$friendship_activity{'activity_id'}",
        $json->encode( { 'rid' => 'internal', 'body' => $BODY } ) )->status_is(200);
    cmp_deeply( $t->tx->res->json, { 'comment_id' => ignore, 'creation_time' => num( time, 2 ) } );

    my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
        { 'activity_id' => $friendship_activity{'activity_id'} } );
    $activity->load( $environment, { 'rid' => $RID } );

    cmp_deeply(
        $activity->get_comments,
        [
            ActivityStream::API::ActivityComment->new(
                'comment_id'    => $t->tx->res->json->{'comment_id'},
                'user_id'       => $user_creator_3_id,
                'body'          => $BODY,
                'creation_time' => $t->tx->res->json->{'creation_time'},
            ),
        ],
    );
}

done_testing();
