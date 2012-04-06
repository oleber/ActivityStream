use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;

use ActivityStream::Util;

use_ok 'ActivityStream';

my $user_creator_1 = ActivityStream::Util::generate_id();
my %activity       = (
    'actor'  => { 'object_id' => "x:person:$user_creator_1" },
    'verb'   => 'post',
    'object' => { 'object_id' => "x:link:1" },
);

my $json = Mojo::JSON->new;
my $t    = Test::Mojo->new('ActivityStream');

{
    $t->post_ok( "/rest/activitystream", $json->encode( \%activity ) )->status_is(200);
    cmp_deeply( $t->tx->res->json, { 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
    $activity{'activity_id'} = $t->tx->res->json->{'activity_id'};
    $activity{'creation_time'} = $t->tx->res->json->{'creation_time'};
}

{
    note("GET single activity: existing");
    $t->get_ok("/rest/activitystream/activity/$activity{'activity_id'}")->status_is(200);
    cmp_deeply( $t->tx->res->json, { %activity, creation_time => num( time, 2 ) } );
}

{
    note("GET single activity: not existing");
    $t->get_ok("/rest/activitystream/activity/not_existing")->status_is(404)->json_content_is( {} );
}

done_testing();
