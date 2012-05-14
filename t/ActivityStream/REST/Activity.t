use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use HTTP::Status qw(:constants);
use Mojo::JSON;
use Storable qw(dclone);
use Readonly;

use ActivityStream::Environment;
use ActivityStream::Util;

local $ActivityStream::AsyncUserAgent::GLOBAL_CACHE_FOR_TEST = {};

use_ok 'ActivityStream';

Readonly my $RID => ActivityStream::Util::generate_id();

my $environment         = ActivityStream::Environment->new;
my $collection_activity = $environment->get_collection_factory->collection_activity;
my $async_user_agent    = $environment->get_async_user_agent;

my $user_creator_1_id = "person:" . ActivityStream::Util::generate_id();
my $user_creator_2_id = "person:" . ActivityStream::Util::generate_id();
my $user_creator_3_id = "person:" . ActivityStream::Util::generate_id();
my $user_creator_4_id = "person:" . ActivityStream::Util::generate_id();

foreach my $user_id ( $user_creator_1_id, $user_creator_2_id, $user_creator_3_id, $user_creator_4_id ) {
    my $user_request = $async_user_agent->create_request_person( { 'object_id' => $user_id, 'rid' => $RID } );
    $async_user_agent->put_response_to( $user_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => 'person ' . $user_id, 'rid' => $RID } ),
    );
}

Readonly my %FRIENDSHIP_ACTIVITY_TEMPLATE => (
    'actor'  => { 'object_id' => $user_creator_1_id },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $user_creator_2_id },
);

my %friendship_activity = %{ dclone \%FRIENDSHIP_ACTIVITY_TEMPLATE };

my $json = Mojo::JSON->new;
my $t    = Test::Mojo->new('ActivityStream');

{
    {
        note("POST a new Activity without rid");

        $t->post_ok( "/rest/activitystream/activity", $json->encode( \%friendship_activity ) )
              ->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'NO_RID_DEFINED' } );
    }

    {
        note("POST a new Activity bad rid");

        $t->post_ok( sprintf( "/rest/activitystream/activity?rid=%s", "person:" . ActivityStream::Util::generate_id ),
            $json->encode( \%friendship_activity ) )->status_is(HTTP_FORBIDDEN)
              ->json_content_is( { 'error' => 'BAD_RID' } );
    }

    {
        note("POST a new Activity with rid to a source");
        $t->post_ok( sprintf( "/rest/activitystream/activity?rid=%s", $user_creator_2_id ),
            $json->encode( \%friendship_activity ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
        $friendship_activity{'activity_id'}   = $t->tx->res->json->{'activity_id'};
        $friendship_activity{'creation_time'} = $t->tx->res->json->{'creation_time'};
        cmp_deeply(
            $collection_activity->find_one_activity( { 'activity_id' => $friendship_activity{'activity_id'} } ),
            superhashof(
                ActivityStream::API::Activity::Friendship->from_rest_request_struct( \%friendship_activity )
                      ->to_db_struct
            ),
        );
    }

    my %second_friendship_activity = %{ dclone \%FRIENDSHIP_ACTIVITY_TEMPLATE };
    {
        note("POST a second Activity with rid internal");
        $t->post_ok( sprintf( '/rest/activitystream/activity?rid=%s' => 'internal' ),
            $json->encode( \%friendship_activity ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );

        $second_friendship_activity{'activity_id'}   = $t->tx->res->json->{'activity_id'};
        $second_friendship_activity{'creation_time'} = $t->tx->res->json->{'creation_time'};

        cmp_deeply(
            $collection_activity->find_one_activity( { 'activity_id' => $second_friendship_activity{'activity_id'} } ),
            superhashof(
                ActivityStream::API::Activity::Friendship->from_rest_request_struct( \%second_friendship_activity )
                      ->to_db_struct
            ),
        );
    }

    {
        note("GET single activity: existing");
        $t->get_ok("/rest/activitystream/activity/$friendship_activity{'activity_id'}?rid=$RID")->status_is(HTTP_OK);

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $t->tx->res->json, $activity->to_rest_response_struct );
    }

    {
        note("GET single activity: not existing");
        $t->get_ok("/rest/activitystream/activity/NotExisting?rid=$RID")->status_is(HTTP_NOT_FOUND)
              ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );
    }

    {
        note("GET single activity: existing");
        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: without rid");

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}")
              ->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'NO_RID_DEFINED' } );

        $activity->set_visibility(1);

        cmp_deeply(
            ActivityStream::API::ActivityFactory->instance_from_db(
                $environment, { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $activity->load( $environment, { 'rid' => $RID } );
        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: BAD rid");

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'BAD_RID' } );

        $activity->set_visibility(1);

        cmp_deeply(
            ActivityStream::API::ActivityFactory->instance_from_db(
                $environment, { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $activity->load( $environment, { 'rid' => $RID } );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: good rid");

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$user_creator_2_id")
              ->status_is(HTTP_OK)->json_content_is( {} );

        $activity->set_visibility(0);

        cmp_deeply(
            ActivityStream::API::ActivityFactory->instance_from_db(
                $environment, { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_NOT_FOUND)->json_content_is( {} );
    }

}

{
    my @expected_likes;

    {
        note("POST User Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        push( @expected_likes,  ActivityStream::API::ActivityLike->new(
            'like_id'       => $t->tx->res->json->{'like_id'},
            'user_id'       => $user_creator_3_id,
            'creation_time' => $t->tx->res->json->{'creation_time'},
        ));
        $expected_likes[-1]->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("POST Second Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_4_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        push( @expected_likes,  ActivityStream::API::ActivityLike->new(
            'like_id'       => $t->tx->res->json->{'like_id'},
            'user_id'       => $user_creator_4_id,
            'creation_time' => $t->tx->res->json->{'creation_time'},
        ));
        $expected_likes[-1]->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("POST User Like Not Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/like/activity/NotExisting",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(HTTP_NOT_FOUND)
              ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );
    }

    {
        note("DELETE First Like Existing activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                $expected_likes[-1]->get_like_id, 'internal',
            ) )->status_is(HTTP_OK)->json_content_is( {} );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        pop @expected_likes;

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Not Existing Like in activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                'NotExisting', 'internal'
            ),
        )->status_is(HTTP_NOT_FOUND)->json_content_is( { 'error' => 'LIKE_NOT_FOUND' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on not existing activity");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                'NotExisting', $expected_likes[-1]->get_like_id, 'internal'
            ),
        )->status_is(HTTP_NOT_FOUND)->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'}, $expected_likes[-1]->get_like_id,
                $user_creator_4_id
            ) )->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'BAD_RID' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on existing activity but without rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s',
                $friendship_activity{'activity_id'},
                $expected_likes[-1]->get_like_id
            ),
            $json->encode( {} ) )->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'NO_RID_DEFINED' } );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( $environment, { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'}, $expected_likes[-1]->get_like_id,
                $user_creator_3_id
            ),
            $json->encode( { 'rid' => $user_creator_3_id } ) )->status_is(HTTP_OK)->json_content_is( {} );

        my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        pop @expected_likes;

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }
}

{
    note("POST User Comment Existing activity");

    Readonly my $BODY => ActivityStream::Util::generate_id;

    $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/comment/activity/$friendship_activity{'activity_id'}",
        $json->encode( { 'rid' => 'internal', 'body' => $BODY } ) )->status_is(HTTP_OK);
    cmp_deeply( $t->tx->res->json, { 'comment_id' => ignore, 'creation_time' => num( time, 2 ) } );

    my $activity = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
        { 'activity_id' => $friendship_activity{'activity_id'} } );
    $activity->load( $environment, { 'rid' => $RID } );

    my $activity_comment = ActivityStream::API::ActivityComment->new(
        'comment_id'    => $t->tx->res->json->{'comment_id'},
        'user_id'       => $user_creator_3_id,
        'body'          => $BODY,
        'creation_time' => $t->tx->res->json->{'creation_time'},
    );
    $activity_comment->load( $environment, { 'rid' => $RID } );

    cmp_deeply( $activity->get_comments, [$activity_comment], );
}

done_testing();
