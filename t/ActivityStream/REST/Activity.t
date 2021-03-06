#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use HTTP::Status qw( :constants );
use Mojo::JSON;
use Readonly;
use Storable qw(dclone);
use Test::MockModule;

use ActivityStream::API::Thing::Person;
use ActivityStream::Environment;
use ActivityStream::Util;

use_ok 'ActivityStream';

Readonly my $RID => ActivityStream::Util::generate_id();

my $t = Test::Mojo->new('ActivityStream');
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );

my $collection_activity = $environment->get_collection_factory->collection_activity;
my $async_user_agent    = $environment->get_async_user_agent;

my $user_creator_1_id = sprintf( '%s:person', ActivityStream::Util::generate_id );
my $user_creator_2_id = sprintf( '%s:person', ActivityStream::Util::generate_id );
my $user_creator_3_id = sprintf( '%s:person', ActivityStream::Util::generate_id );
my $user_creator_4_id = sprintf( '%s:person', ActivityStream::Util::generate_id );

foreach my $user_id ( $user_creator_1_id, $user_creator_2_id, $user_creator_3_id, $user_creator_4_id ) {
    my $user = ActivityStream::API::Thing::Person->new( { 'environment' => $environment, 'object_id' => $user_id } );

    $t->app->routes->get( $user->create_request( { 'rid' => $RID } ) )->to(
        'cb' => sub {
            $user->create_test_response( {
                    'first_name' => 'person ' . $user_id,
                    'rid'        => $RID
                } )->(shift);
        } );
}

Readonly my %FRIENDSHIP_ACTIVITY_TEMPLATE => (
    'actor'  => { 'object_id' => $user_creator_1_id },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $user_creator_2_id },
);

my %friendship_activity = %{ dclone \%FRIENDSHIP_ACTIVITY_TEMPLATE };

my $json = Mojo::JSON->new;

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
                ActivityStream::API::Activity::Friendship->from_rest_request_struct( $environment,
                    \%friendship_activity )->to_db_struct
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
                ActivityStream::API::Activity::Friendship->from_rest_request_struct( $environment,
                    \%second_friendship_activity )->to_db_struct
            ),
        );
    }

    {
        note("GET single activity: existing");
        $t->get_ok("/rest/activitystream/activity/$friendship_activity{'activity_id'}?rid=$RID")->status_is(HTTP_OK);

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        cmp_deeply( $t->tx->res->json, $activity->to_rest_response_struct );
    }

    {
        note("GET single activity: not existing");
        $t->get_ok("/rest/activitystream/activity/NotExisting?rid=$RID")->status_is(HTTP_NOT_FOUND)
              ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );
    }

    {
        note("GET single activity: existing");
        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: without rid");

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}")
              ->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'NO_RID_DEFINED' } );

        $activity->set_visibility(1);

        cmp_deeply(
            $environment->get_activity_factory->activity_instance_from_db(
                { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $activity->load( { 'rid' => $RID } );
        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: BAD rid");

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'BAD_RID' } );

        $activity->set_visibility(1);

        cmp_deeply(
            $environment->get_activity_factory->activity_instance_from_db(
                { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $activity->load( { 'rid' => $RID } );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_OK)->json_content_is( $activity->to_rest_response_struct );
    }

    {
        note("DELETE single activity: good rid");

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $second_friendship_activity{'activity_id'} } );

        $t->delete_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$user_creator_2_id")
              ->status_is(HTTP_OK)->json_content_is( {} );

        $activity->set_visibility(0);

        cmp_deeply(
            $environment->get_activity_factory->activity_instance_from_db(
                { 'activity_id' => $second_friendship_activity{'activity_id'} }
            ),
            $activity
        );

        $t->get_ok("/rest/activitystream/activity/$second_friendship_activity{'activity_id'}?rid=$RID")
              ->status_is(HTTP_NOT_FOUND)->json_content_is( {} );
    }

}

{
    note('Test Like');
    my @expected_likes;

    {
        note("POST User Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        push(
            @expected_likes,
            ActivityStream::API::ActivityLike->new(
                'environment' => $environment,
                'like_id'     => $t->tx->res->json->{'like_id'},
                'creator'     => ActivityStream::API::Thing::Person->new(
                    'environment' => $environment,
                    'object_id'   => $user_creator_3_id
                ),
                'creation_time' => $t->tx->res->json->{'creation_time'},
            ) );

        $expected_likes[-1]->load( { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("POST Second Like Existing activity");

        $t->post_ok( "/rest/activitystream/user/$user_creator_4_id/like/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal' } ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'like_id' => re(qr/^[a-zA-Z]{10,}$/), 'creation_time' => num( time, 2 ) } );

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        push(
            @expected_likes,
            ActivityStream::API::ActivityLike->new(
                'environment' => $environment,
                'like_id'     => $t->tx->res->json->{'like_id'},
                'creator'     => ActivityStream::API::Thing::Person->new(
                    'environment' => $environment,
                    'object_id'   => $user_creator_4_id
                ),
                'creation_time' => $t->tx->res->json->{'creation_time'},
            ) );
        $expected_likes[-1]->load( { 'rid' => $RID } );

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

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

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

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

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

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                $expected_likes[-1]->get_like_id,
                $user_creator_4_id
            ) )->status_is(HTTP_FORBIDDEN)->json_content_is( { 'error' => 'BAD_RID' } );

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

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

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }

    {
        note("DELETE Like on existing activity but with bad rid");

        $t->delete_ok(
            sprintf(
                '/rest/activitystream/activity/%s/like/%s?rid=%s',
                $friendship_activity{'activity_id'},
                $expected_likes[-1]->get_like_id,
                $user_creator_3_id
            ),
            $json->encode( { 'rid' => $user_creator_3_id } ) )->status_is(HTTP_OK)->json_content_is( {} );

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        pop @expected_likes;

        cmp_deeply( $activity->get_likers, \@expected_likes );
    }
}

{
    note('Test comment');
    {
        note("POST User Comment Existing activity");

        Readonly my $BODY => ActivityStream::Util::generate_id;

        $t->post_ok(
            "/rest/activitystream/user/$user_creator_3_id/comment/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal', 'body' => $BODY } ) )->status_is(HTTP_OK);
        cmp_deeply( $t->tx->res->json, { 'comment_id' => ignore, 'creation_time' => num( time, 2 ) } );

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );
        $activity->load( { 'rid' => $RID } );

        my $activity_comment = ActivityStream::API::ActivityComment->new(
            'environment' => $environment,
            'comment_id'  => $t->tx->res->json->{'comment_id'},
            'creator'     => ActivityStream::API::Thing::Person->new(
                'environment' => $environment,
                'object_id'   => $user_creator_3_id
            ),
            'body'          => $BODY,
            'creation_time' => $t->tx->res->json->{'creation_time'},
        );
        $activity_comment->load( { 'rid' => $RID } );

        cmp_deeply( $activity->get_comments, [$activity_comment], );
    }
}

{
    note('Test recommend');

    my @callback;
    my $cb;
    my $mock = Test::MockModule->new('ActivityStream::API::Activity::Friendship');
    $mock->mock(
        'save_recommendation',
        sub {
            push( @callback, [ 'save_recommendation' => @_ ] );
            return $cb->();
        },
    );

    {
        note("POST User recommend Existing activity no activity generated");
        @callback = ();
        $cb = sub {return};
        Readonly my $BODY => ActivityStream::Util::generate_id;

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        $t->post_ok(
            "/rest/activitystream/user/$user_creator_3_id/recommend/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal', 'body' => $BODY } ) )->status_is(HTTP_OK)->json_content_is( {} );
        cmp_deeply(
            \@callback,
            [ [
                    'save_recommendation' => ignore,
                    { 'creator' => { 'object_id' => $user_creator_3_id }, 'body' => $BODY } ] ] );
    }

    {
        note("POST User recommend Existing activity and generate activity");
        @callback = ();

        my %test_friendship_activity = %{ dclone \%FRIENDSHIP_ACTIVITY_TEMPLATE };
        my $new_activity             = $environment->get_activity_factory->activity_instance_from_rest_request_struct(
            \%test_friendship_activity );
        $cb = sub { return $new_activity };
        Readonly my $BODY => ActivityStream::Util::generate_id;

        my $activity = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $friendship_activity{'activity_id'} } );

        $t->post_ok(
            "/rest/activitystream/user/$user_creator_3_id/recommend/activity/$friendship_activity{'activity_id'}",
            $json->encode( { 'rid' => 'internal', 'body' => $BODY } ) )->status_is(HTTP_OK)->json_content_is( {
                'activity_id'   => $new_activity->get_activity_id,
                'creation_time' => $new_activity->get_creation_time,
            } );

        cmp_deeply(
            \@callback,
            [ [
                    'save_recommendation' => ignore,
                    { 'creator' => { 'object_id' => $user_creator_3_id }, 'body' => $BODY } ] ] );
    }

    {
        note("POST User recommend Not Existing activity");
        @callback = ();
        $cb = sub {return};
        Readonly my $BODY => ActivityStream::Util::generate_id;

        my $not_existing_activity_id = sprintf( '%s:activity', ActivityStream::Util::generate_id );

        $t->post_ok( "/rest/activitystream/user/$user_creator_3_id/recommend/activity/$not_existing_activity_id",
            $json->encode( { 'rid' => $user_creator_3_id, 'body' => $BODY } ) )->status_is(HTTP_NOT_FOUND)
              ->json_content_is( { 'error' => 'ACTIVITY_NOT_FOUND' } );

        cmp_deeply( \@callback, [] );
    }

}

done_testing;
