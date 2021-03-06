#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use HTTP::Status qw( :constants );
use Readonly;

use ActivityStream::API::Activity::Friendship;
use ActivityStream::API::Thing::Person;
use ActivityStream::Environment;
use ActivityStream::Util;

use_ok 'ActivityStream';

Readonly my $RID => ActivityStream::Util::generate_id();

my $t = Test::Mojo->new('ActivityStream');
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );

my $collection_activity = $environment->get_collection_factory->collection_activity;
my $async_user_agent    = $environment->get_async_user_agent;

Readonly my $VIEWER_USER_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );

my @USERS = ( map { sprintf( '%s:person', ActivityStream::Util::generate_id ) } ( 0 .. 9 ) );

Readonly my $USER_1_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );

#   prepare load of all persons
my %person_object_for;
foreach my $person_id ( @USERS, $USER_1_ID, $USER_2_ID, $USER_3_ID, $VIEWER_USER_ID ) {

    my $person
          = ActivityStream::API::Thing::Person->new( { 'environment' => $environment, 'object_id' => $person_id } );

    $t->app->routes->get( $person->create_request( { 'rid' => $RID } ) )->to(
        'cb' => sub {
            $person->create_test_response( {
                    'first_name' => "first name $person_id",
                    'rid'        => $RID
                } )->(shift);
        } );

    my $object_person
          = ActivityStream::API::Thing::Person->new( { 'environment' => $environment, 'object_id' => $person_id } );
    $object_person->load( { 'rid' => $RID } );
    $person_object_for{$person_id} = $object_person;
}

sub request_for {
    my ( $viewer_user_id, @args ) = @_;
    my $url = Mojo::URL->new("/rest/activitystream/activity/user/$viewer_user_id/activitystream");
    return $url->query( \@args );
}

{
    note('Empty ActivityStream');
    my $url = request_for(
        $VIEWER_USER_ID,
        'see_source_id'    => [ $USER_1_ID, $USER_2_ID ],
        'ignore_source_id' => [$USER_3_ID],
    );

    $t->get_ok($url)->status_is(HTTP_OK)->json_content_is( { 'activities' => [] } );
}

my $delay = 0;
my $EPOCH = time;

my @user_1_activities = map {
    $delay -= 24 * 60 * 60;
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( $environment, {
            'actor'         => { 'object_id' => $USER_1_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => $_ },
            'creation_time' => $EPOCH + $delay,
        },
          )->save_in_db
} (@USERS);

my @user_2_activities = map {
    $delay -= 24 * 60 * 60;
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( $environment, {
            'actor'         => { 'object_id' => $USER_2_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => "$_" },
            'creation_time' => $EPOCH + $delay++,
        },
          )->save_in_db
} (@USERS);

foreach my $activity ( @user_1_activities, @user_2_activities ) {
    $activity->load( { 'rid' => $RID } );
}

{
    note('Not Empty ActivityStream');
    my $url = request_for(
        $VIEWER_USER_ID,
        'see_source_id'    => [ $USER_1_ID, $USER_2_ID ],
        'ignore_source_id' => [$USER_3_ID],
        'limit'            => 5,
        'rid'              => $RID,
    );

    my @expected = map { $_->to_rest_response_struct } @user_1_activities[ 0 .. 4 ];
    $t->get_ok($url)->status_is(HTTP_OK)->json_content_is( { 'activities' => \@expected } );
}

{
    note('Invert Sources');
    my $url = request_for(
        $VIEWER_USER_ID,
        'see_source_id'    => [ $USER_1_ID, $USER_2_ID ],
        'ignore_source_id' => [$USER_3_ID],
        'limit'            => 5,
        'rid'              => $RID,
    );

    my @expected = map { $_->to_rest_response_struct } @user_1_activities[ 0 .. 4 ];
    $t->get_ok($url)->status_is(HTTP_OK)->json_content_is( { 'activities' => \@expected } );
}

{
    note('Ignore activities');

    my $url = request_for(
        $VIEWER_USER_ID,
        'see_source_id'    => [ $USER_1_ID, $USER_2_ID ],
        'ignore_source_id' => [$USER_3_ID],
        'ignore_activity'  => [ map         { $_->get_activity_id } @user_1_activities[ 0 .. 4 ] ],
        'limit'            => 5,
        'rid'              => $RID,
    );

    my @expected = map { $_->to_rest_response_struct } @user_1_activities[ 5 .. 9 ];
    $t->get_ok($url)->status_is(HTTP_OK)->json_content_is( { 'activities' => \@expected } );
}

{
    note('Ignore sources');
    my $url = request_for(
        $VIEWER_USER_ID,
        'see_source_id'    => [ $USER_1_ID, $USER_2_ID ],
        'ignore_source_id' => [ @USERS[ 0 .. 4 ] ],
        'limit'            => 5,
        'rid'              => $RID,
    );

    my @expected = map { $_->to_rest_response_struct } @user_1_activities[ 5 .. 9 ];
    $t->get_ok($url)->status_is(HTTP_OK)->json_content_is( { 'activities' => \@expected } );
}

done_testing;
