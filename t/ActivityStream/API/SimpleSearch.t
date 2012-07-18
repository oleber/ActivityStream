#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use List::Util qw(shuffle);
use Mojo::JSON;
use Readonly;
use Test::MockModule;
use Time::Local;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );

Readonly my $PKG => 'ActivityStream::API::SimpleSearch';
use_ok($PKG);

Readonly my $NOW => time;

Readonly my $USER_1_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_4_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_5_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );

my $delay        = 0;
my $activity_1_1 = ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_1_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_2 = ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_2_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_3 = ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_3_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_4 = ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_4_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_5 = ActivityStream::API::Activity::Friendship->from_rest_request_struct( {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_5_ID },
        'creation_time' => $NOW + $delay,
    },
);

foreach my $activity ( shuffle( $activity_1_1, $activity_1_2, $activity_1_3, $activity_1_4, $activity_1_5 ) ) {
    $activity->save_in_db($environment);
}

{
    note('test cursor intervals');

    my $cursor = ActivityStream::API::SimpleSearch::Cursor->new(
        environment => $environment,
        filter      => ActivityStream::API::SimpleSearch::Filter->new(
            'consumer_id'    => sprintf( '%s:person',   ActivityStream::Util::generate_id ),
            'see_source_ids' => [ sprintf( '%s:person', ActivityStream::Util::generate_id ) ],
        ),
        now_time => 1341556469,
    );

    my @expected = (
        3726540,    # now
        1863261,    # previous 2 hours
        931622,     # previous 4 hours
        465803,     # previous 8 hours
        232894,     # previous 16 hours
        232884,     # previous 16 hours
        116435,     # repeate previous 32 hours
        116425,
        58206,
        29097,
        29087,
        14538,
        14528,
        7259,
        7249,
        7239,
        7229,
        7219,
        7209,
        7199,
    );
    eq_or_diff( $cursor->get_intervals, \@expected );
    is( scalar( @{ $cursor->get_intervals } ), 20 );

    $PKG->search(
        $environment,
        {
            'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
            'see_source_ids' => [$USER_1_ID],
        },
    );

}

{
    note('basic search');

    my @callbacks;

    my $mongodb_collection_mock = Test::MockModule->new('MongoDB::Collection');
    $mongodb_collection_mock->mock(
        'find',
        sub {
            my ( $self, $query ) = @_;
            push( @callbacks, [ 'find' => @_ ] );

            my $explain = $mongodb_collection_mock->original('find')->(@_)->explain;
            isnt( $explain->{'cursor'} => 'BasicCursor' )
                  or diag( 'No Index for: ' . Dumper($query) . ' with explain ' . Dumper($explain) );

            return $mongodb_collection_mock->original('find')->(@_);
        },
    );

    {
        note('1 source');

        my $cursor = $PKG->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [$USER_1_ID],
            },
        );

        my @expected = (
            ( map { [ 'find' => ignore, { 'timebox' => { '$in' => ["$_:$USER_1_ID"] } } ] } @{ $cursor->get_intervals } ),
            (
                map { [ 'find' => ignore, { 'activity_id' => $_->get_activity_id } ] }
                      ( $activity_1_1, $activity_1_2, $activity_1_3, $activity_1_4, $activity_1_5 ),
            ),
        );

        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_1->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_2->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_3->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_4->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_5->to_db_struct );
        cmp_deeply( $cursor->next_activity,               undef );

        cmp_deeply( \@callbacks, bag(@expected) );
    }

    {
        note('2 sources');

        my $cursor = $PKG->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [ $USER_2_ID,         $USER_3_ID ],
            },
        );

        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_2->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_3->to_db_struct );
        cmp_deeply( $cursor->next_activity,               undef );
    }

    {
        note('reverse 2 sources');

        my $cursor = $PKG->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [ $USER_3_ID,         $USER_2_ID ],
            },
        );

        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_2->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_3->to_db_struct );
        cmp_deeply( $cursor->next_activity,               undef );
    }
}

done_testing;
