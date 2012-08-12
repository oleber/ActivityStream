#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use List::Util qw(shuffle);
use Readonly;
use Test::MockModule;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );

Readonly my $PKG => 'ActivityStream::API::Search';
use_ok($PKG);

Readonly my $NOW => time;

Readonly my $USER_1_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_4_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_5_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );

my $delay        = 0;
my $activity_1_1 = ActivityStream::API::Activity::Friendship->from_rest_request_struct(
    $environment,
    {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_1_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_2 = ActivityStream::API::Activity::Friendship->from_rest_request_struct(
    $environment,
    {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_2_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_3 = ActivityStream::API::Activity::Friendship->from_rest_request_struct(
    $environment,
    {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_3_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_4 = ActivityStream::API::Activity::Friendship->from_rest_request_struct(
    $environment,
    {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_4_ID },
        'creation_time' => $NOW + $delay,
    },
);

$delay -= 1_500;
my $activity_1_5 = ActivityStream::API::Activity::Friendship->from_rest_request_struct(
    $environment,
    {
        'actor'         => { 'object_id' => $USER_1_ID },
        'verb'          => 'friendship',
        'object'        => { 'object_id' => $USER_5_ID },
        'creation_time' => $NOW + $delay,
    },
);

foreach my $activity ( shuffle( $activity_1_1, $activity_1_2, $activity_1_3, $activity_1_4, $activity_1_5 ) ) {
    $activity->save_in_db;
}

subtest 'test cursor intervals', sub {
    Readonly my $NOW_TIME => 1341556469;
    Readonly my @EXPECTED => (
        MIME::Base64::encode_base64url( pack( 'V', 37265400 ) ),    # now
        MIME::Base64::encode_base64url( pack( 'V', 18632601 ) ),    # previous 2 hours
        MIME::Base64::encode_base64url( pack( 'V', 9316202 ) ),     # previous 4 hours
        MIME::Base64::encode_base64url( pack( 'V', 4658003 ) ),     # previous 8 hours
        MIME::Base64::encode_base64url( pack( 'V', 2328904 ) ),     # previous 16 hours
        MIME::Base64::encode_base64url( pack( 'V', 2328804 ) ),     # repeate previous 16 hours
        MIME::Base64::encode_base64url( pack( 'V', 1164305 ) ),     # previous 32 hours
        MIME::Base64::encode_base64url( pack( 'V', 1164205 ) ),     # repeate previous 32 hours
        MIME::Base64::encode_base64url( pack( 'V', 582006 ) ),      # previous 64 hours
        MIME::Base64::encode_base64url( pack( 'V', 290907 ) ),      # previous 128 hours
        MIME::Base64::encode_base64url( pack( 'V', 290807 ) ),      # repeate previous 128 hours
        MIME::Base64::encode_base64url( pack( 'V', 145308 ) ),      # previous 256 hours
        MIME::Base64::encode_base64url( pack( 'V', 145208 ) ),      # repeate previous 256 hours
        MIME::Base64::encode_base64url( pack( 'V', 72509 ) ),       # previous 512 hours
        MIME::Base64::encode_base64url( pack( 'V', 72409 ) ),       # repeate previous 512 hours
        MIME::Base64::encode_base64url( pack( 'V', 36110 ) ),       # previous 1024 hours
        MIME::Base64::encode_base64url( pack( 'V', 36010 ) ),       # repeate previous 1024 hours
        MIME::Base64::encode_base64url( pack( 'V', 17911 ) ),       # previous 2048 hours
        MIME::Base64::encode_base64url( pack( 'V', 17811 ) ),       # repeate previous 2048 hours
        MIME::Base64::encode_base64url( pack( 'V', 8812 ) ),        # previous 4096 hours
        MIME::Base64::encode_base64url( pack( 'V', 4313 ) ),        # previous 8192 hours
        MIME::Base64::encode_base64url( pack( 'V', 4213 ) ),        # repeate previous 8192 hours
        MIME::Base64::encode_base64url( pack( 'V', 2014 ) ),        # previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1914 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1814 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1714 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1614 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1514 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1414 ) ),        # repeate previous 16384 hours
        MIME::Base64::encode_base64url( pack( 'V', 1314 ) ),        # repeate previous 16384 hours
    );

    {
        my $cursor = ActivityStream::API::Search::Cursor->new(
            environment => $environment,
            filter      => ActivityStream::API::Search::Filter->new(
                'consumer_id'    => sprintf( '%s:person',   ActivityStream::Util::generate_id ),
                'see_source_ids' => [ sprintf( '%s:person', ActivityStream::Util::generate_id ) ],
            ),
            now_time => $NOW_TIME,
        );

        eq_or_diff( $cursor->get_intervals, \@EXPECTED );
    }

    $PKG->search(
        $environment,
        {
            'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
            'see_source_ids' => [$USER_1_ID],
        },
    );
};

subtest 'basic search', sub {
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

    subtest '1 source', sub {
        my $cursor = $PKG->search(
            $environment,
            {
                'consumer_id'    => sprintf( "person:%s", ActivityStream::Util::generate_id ),
                'see_source_ids' => [$USER_1_ID],
            },
        );

        my @expected = ( (
                map { [
                        'find' => ignore,
                        {
                            'timebox' => {
                                '$in' => [
                                    sprintf(
                                        '%s:%s:%s',
                                        $_,
                                        MIME::Base64::encode_base64url(
                                            pack( 'V', ActivityStream::Util::calc_hash($USER_1_ID) )
                                        ),
                                        $USER_1_ID,
                                    ) ] } } ]
                      } @{ $cursor->get_intervals }
            ),
            (
                map {
                    [ 'find' => ignore, { 'activity_id' => $_->get_activity_id } ]
                      } ( $activity_1_1, $activity_1_2, $activity_1_3, $activity_1_4, $activity_1_5 ),
            ),
        );

        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_1->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_2->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_3->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_4->to_db_struct );
        cmp_deeply( $cursor->next_activity->to_db_struct, $activity_1_5->to_db_struct );
        cmp_deeply( $cursor->next_activity,               undef );

        cmp_deeply( \@callbacks, bag(@expected) );
    };

    subtest '2 source', sub {

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
    };

    subtest 'reverse 2 sources', sub {

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
    };
};

done_testing;
