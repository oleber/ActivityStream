use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

Readonly my $environment => ActivityStream::Environment->new;

Readonly my $PKG => 'ActivityStream::API::Search';
use_ok($PKG);

Readonly my $EPOCH => time;

my @USERS = ( map { sprintf( "person:%s", ActivityStream::Util::generate_id ) } ( 0 .. 9 ) );

Readonly my $USER_1_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

my $delay = 0;

my @user_1_activities = map {
    $delay++;
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
            'actor'         => { 'object_id' => $USER_1_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => $_ },
            'creation_time' => $EPOCH + $delay,
        },
          )->save_in_db($environment)
} ( @USERS );

my @user_2_activities = map {
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
            'actor'         => { 'object_id' => $USER_2_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => "$_" },
            'creation_time' => $EPOCH + $delay++,
        },
          )->save_in_db($environment)
} ( @USERS );

my @user_activities = ( @user_1_activities, @user_2_activities );

cmp_deeply(
    $PKG->search( $environment, { 'see_sources' => [$USER_1_ID] } )->next_activity->to_db_struct,
    $user_1_activities[-1]->to_db_struct
);

cmp_deeply(
    $PKG->search( $environment, { 'see_sources' => [$USER_2_ID] } )->next_activity->to_db_struct,
    $user_2_activities[-1]->to_db_struct
);

done_testing();
