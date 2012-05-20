use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;
use Time::Local;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

Readonly my $environment => ActivityStream::Environment->new;

Readonly my $PKG => 'ActivityStream::API::Search';
use_ok($PKG);

Readonly my $TODAY            => timelocal( 0, 0, 6, ( localtime( time - 0 * 24 * 60 * 60 ) )[ 3, 4, 5 ] );
Readonly my $YESTERDAY        => timelocal( 0, 0, 6, ( localtime( time - 1 * 24 * 60 * 60 ) )[ 3, 4, 5 ] );
Readonly my $BEFORE_YESTERDAY => timelocal( 0, 0, 6, ( localtime( time - 2 * 24 * 60 * 60 ) )[ 3, 4, 5 ] );

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
            'creation_time' => $TODAY + $delay,
        },
          )->save_in_db($environment)
} (@USERS);

my @user_2_activities = map {
    $delay++;
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
            'actor'         => { 'object_id' => $USER_2_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => $_ },
            'creation_time' => $YESTERDAY + $delay,
        },
          )->save_in_db($environment)
} (@USERS);

my @user_3_activities = map {
    $delay++;
    ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
            'actor'         => { 'object_id' => $USER_3_ID },
            'verb'          => 'friendship',
            'object'        => { 'object_id' => $_ },
            'creation_time' => $BEFORE_YESTERDAY + $delay,
        },
          )->save_in_db($environment)
} (@USERS);

my @user_activities = ( @user_1_activities, @user_2_activities, @user_3_activities );

my %activities_map;
foreach my $activity (@user_activities) {
    $activities_map{ $activity->get_actor->get_object_id }{ $activity->get_object->get_object_id } = $activity;
}

my @ALL_USERS = ( @USERS, $USER_1_ID, $USER_2_ID, $USER_3_ID );

my $collection_source   = $environment->get_collection_factory->collection_source;
my $collection_consumer = $environment->get_collection_factory->collection_consumer;

{
    note('test Sources');
    foreach my $actor_id ( $USER_1_ID, $USER_2_ID, $USER_3_ID ) {
        my $day;    # setted inside the cicle
        foreach my $source (@USERS) {
            my $activity = $activities_map{$actor_id}{$source};
            $day = ActivityStream::Util::get_day_of( $activity->get_creation_time );
            cmp_deeply(
                [ $collection_source->find_sources( { 'source_id' => $source, 'day' => $day } )->all ],
                [ {
                        '_id'       => ignore,
                        'source_id' => $source,
                        'status'    => ignore,
                        'day'       => $day,
                        'activity'  => { $activity->get_activity_id => $activity->get_creation_time },
                    },
                ],
            );
        }

        cmp_deeply(
            [ $collection_source->find_sources( { 'source_id' => $actor_id, 'day' => $day } )->all ],
            [ {
                    '_id'       => ignore,
                    'source_id' => $actor_id,
                    'status'    => ignore,
                    'day'       => $day,
                    'activity'  => {
                        map { $_->get_activity_id => $_->get_creation_time }
                              values( %{ $activities_map{$actor_id} } )

                    },
                },
            ],
        );
    } ## end foreach my $actor_id ( $USER_1_ID...)
}

my $today_day            = ActivityStream::Util::get_day_of($TODAY);
my $yesterday_day        = ActivityStream::Util::get_day_of($YESTERDAY);
my $before_yesterday_day = ActivityStream::Util::get_day_of($BEFORE_YESTERDAY);

{
    note('basic search');

    {
        note('1 source');
        Readonly my $CONSUMER_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

        my $cursor = ActivityStream::API::Search->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [$USER_1_ID],
            },
        );

        foreach my $activity ( reverse @user_1_activities ) {
            cmp_deeply( $cursor->next_activity->to_db_struct, $activity->to_db_struct );
        }
        cmp_deeply( $cursor->next_activity, undef );
    }

    {
        note('2 source');
        Readonly my $CONSUMER_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );
        my $cursor = $PKG->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [ $USER_2_ID,         $USER_3_ID ], }, );

        foreach my $activity ( reverse( @user_3_activities, @user_2_activities ) ) {
            cmp_deeply( $cursor->next_activity->to_db_struct, $activity->to_db_struct );
        }
        cmp_deeply( $cursor->next_activity, undef );
    }
}

{
    note('Search with Sources on a single day');

    Readonly my $CONSUMER_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

    cmp_deeply( [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
        [], 'Verify that is empty' );

    my $cursor = ActivityStream::API::Search->search(
        $environment,
        ActivityStream::API::Search::Filter->new(
            { 'consumer_id' => $CONSUMER_ID, 'see_source_ids' => [ $USER_1_ID, $USER_2_ID, $USER_3_ID, ] }
        ),
    );
    cmp_deeply( $cursor->next_activity, $activities_map{$USER_1_ID}{ $USERS[-1] } );
    $environment->get_async_user_agent->load_all;

    cmp_deeply(
        [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
        bag( {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $today_day,
                'sources'     => {
                    $USER_1_ID => {
                        'status'   => ignore,
                        'activity' => { map { $_->get_activity_id => $_->get_creation_time } @user_1_activities },
                    },
                },
            },
            {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $yesterday_day,
                'sources'     => {
                    $USER_2_ID => {
                        'status'   => ignore,
                        'activity' => { map { $_->get_activity_id => $_->get_creation_time } @user_2_activities },
                    },
                },
            }
        ),
    );
}

{
    note('Search with Sources on multiple days');

    Readonly my $CONSUMER_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

    cmp_deeply( [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
        [], 'Verify that is empty' );

    my $cursor
          = ActivityStream::API::Search->search( $environment,
        ActivityStream::API::Search::Filter->new( { 'consumer_id' => $CONSUMER_ID, 'see_source_ids' => [@USERS] } ),
          );
    cmp_deeply( $cursor->next_activity, $activities_map{$USER_1_ID}{ $USERS[-1] } );
    $environment->get_async_user_agent->load_all;

    cmp_deeply(
        [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
        bag( {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $today_day,
                'sources'     => {
                    map {
                        $_ => {
                            'status'   => ignore,
                            'activity' => {
                                $activities_map{$USER_1_ID}{$_}->get_activity_id =>
                                      $activities_map{$USER_1_ID}{$_}->get_creation_time
                            } }
                          } @USERS
                },
            },
            {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $yesterday_day,
                'sources'     => {
                    map {
                        $_ => {
                            'status'   => ignore,
                            'activity' => {
                                $activities_map{$USER_2_ID}{$_}->get_activity_id =>
                                      $activities_map{$USER_2_ID}{$_}->get_creation_time
                            } }
                          } @USERS
                },
            }
        ),
    );
}

{
    note('Search with Sources on multiple days');

    Readonly my $CONSUMER_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

    cmp_deeply( [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
        [], 'Verify that is empty' );

    my $cursor = ActivityStream::API::Search->search(
        $environment,
        ActivityStream::API::Search::Filter->new(
            { 'consumer_id' => $CONSUMER_ID, 'see_source_ids' => [ $USERS[0] ] }
        ),
    );

    my @expected_consumer_rows;

    {
        note('Get first Activity');

        cmp_deeply( $cursor->next_activity, $activities_map{$USER_1_ID}{ $USERS[0] } );
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );

        push(
            @expected_consumer_rows,
            {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $today_day,
                'sources'     => {
                    $USERS[0] => {
                        'status'   => ignore,
                        'activity' => {
                            $activities_map{$USER_1_ID}{ $USERS[0] }->get_activity_id =>
                                  $activities_map{$USER_1_ID}{ $USERS[0] }->get_creation_time
                        },
                    },
                },
            },
            {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $yesterday_day,
                'sources'     => {
                    $USERS[0] => {
                        'status'   => ignore,
                        'activity' => {
                            $activities_map{$USER_2_ID}{ $USERS[0] }->get_activity_id =>
                                  $activities_map{$USER_2_ID}{ $USERS[0] }->get_creation_time
                        },
                    },
                }
            },
        );
        $environment->get_async_user_agent->load_all;
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );
    }

    {
        note('Get Second activity, no Costumer needed');
        cmp_deeply( $cursor->next_activity, $activities_map{$USER_2_ID}{ $USERS[0] } );
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );
        $environment->get_async_user_agent->load_all;
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );
    }

    {
        note('Get Third activity, Costumer updated');

        cmp_deeply( $cursor->next_activity, $activities_map{$USER_3_ID}{ $USERS[0] } );
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );

        push(
            @expected_consumer_rows,
            {
                '_id'         => ignore,
                'consumer_id' => $CONSUMER_ID,
                'day'         => $before_yesterday_day,
                'sources'     => {
                    $USERS[0] => {
                        'status'   => ignore,
                        'activity' => {
                            $activities_map{$USER_3_ID}{ $USERS[0] }->get_activity_id =>
                                  $activities_map{$USER_3_ID}{ $USERS[0] }->get_creation_time
                        },
                    },
                }
            },
        );

        $environment->get_async_user_agent->load_all;
        cmp_deeply(
            [ $collection_consumer->find_consumers( { 'consumer_id' => $CONSUMER_ID } )->all ],
            bag(@expected_consumer_rows),
        );
    }

}

done_testing;
