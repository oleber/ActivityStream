#!/usr/bin/perl

use Mojo::Base -strict;

use Test::MockModule;
use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;
use Storable qw(dclone);

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;

Readonly my $PKG => 'ActivityStream::API::Activity::PersonRecommendPerson';

use_ok($PKG);
isa_ok( $PKG => 'ActivityStream::API::Activity' );

is( $PKG->get_attribute_base_class('actor'),  'ActivityStream::API::Object::Person' );
is( $PKG->get_attribute_base_class('object'), 'ActivityStream::API::Object::Person' );

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );
my $async_user_agent = $environment->get_async_user_agent;

Readonly my $RID => ActivityStream::Util::generate_id();

Readonly my $PERSON_ACTOR_ID           => 'actorID:person';
Readonly my $PERSON_OBJECT_ID          => 'objectID:person';
Readonly my $PERSON_SUPER_COMMENTER_ID => 'SuperCommenterID:person';
Readonly my $PERSON_COMMENTER_ID       => 'commenterID:person';

foreach my $person_id ( $PERSON_ACTOR_ID, $PERSON_OBJECT_ID, $PERSON_SUPER_COMMENTER_ID, $PERSON_COMMENTER_ID ) {
    my $actor = ActivityStream::API::Object::Person->new( 'object_id' => $person_id );
    $t->app->routes->get( $actor->create_request( $environment, { 'rid' => $RID } ) )
          ->to( 'cb' => $actor->create_test_response( { 'rid' => $RID } ) );
}

###
###
###

my %SUPER_PARENT_DATA = (
    'actor'  => { 'object_id' => $PERSON_ACTOR_ID },
    'verb'   => 'friendship',
    'object' => { 'object_id' => $PERSON_OBJECT_ID },
);

our $super_parent_activity
      = $environment->get_activity_factory->activity_instance_from_rest_request_struct( dclone {%SUPER_PARENT_DATA} );
$super_parent_activity->save_in_db($environment);
$super_parent_activity->load( $environment, { 'rid' => $RID } );

my %expected_super_parent_data_to_db_struct = (
    %SUPER_PARENT_DATA,
    'timebox'       => ignore,
    'activity_id'   => $super_parent_activity->get_activity_id,
    'comments'      => [],
    'creation_time' => num( time, 5 ),
    'likers'        => [],
    'sources'       => [ $PERSON_ACTOR_ID, $PERSON_OBJECT_ID ],
    'visibility'    => 1,
);

my %expected_super_parent_data_to_rest_response_struct = (
    'activity_id'   => $super_parent_activity->get_activity_id,
    'actor'         => $super_parent_activity->get_actor->to_rest_response_struct,
    'verb'          => $super_parent_activity->get_verb,
    'object'        => $super_parent_activity->get_object->to_rest_response_struct,
    'comments'      => [],
    'creation_time' => num( time, 5 ),
    'likers'        => [],
);

###
###
###

my %PARENT_DATA = (
    'actor'                    => { 'object_id' => $PERSON_SUPER_COMMENTER_ID },
    'verb'                     => 'recommend',
    'object'                   => { 'object_id' => $PERSON_OBJECT_ID },
    'super_parent_activity_id' => $super_parent_activity->get_activity_id,
    'parent_activity_id'       => $super_parent_activity->get_activity_id,
);

our $parent_activity
      = $environment->get_activity_factory->activity_instance_from_rest_request_struct( dclone {%PARENT_DATA} );
$parent_activity->save_in_db($environment);
$parent_activity->load( $environment, { 'rid' => $RID } );
isa_ok( $parent_activity, $PKG );

my %expected_parent_data_to_db_struct = (
    %PARENT_DATA,
    'timebox'       => ignore,
    'activity_id'   => $parent_activity->get_activity_id,
    'comments'      => [],
    'creation_time' => num( time, 5 ),
    'likers'        => [],
    'sources'       => [$PERSON_SUPER_COMMENTER_ID],
    'visibility'    => 1,
);
my %expected_parent_data_to_rest_response_struct = (
    'activity_id'           => $parent_activity->get_activity_id,
    'actor'                 => $parent_activity->get_actor->to_rest_response_struct,
    'verb'                  => $parent_activity->get_verb,
    'object'                => $parent_activity->get_object->to_rest_response_struct,
    'comments'              => [],
    'creation_time'         => num( time, 5 ),
    'likers'                => [],
    'parent_activity_id'    => $super_parent_activity->get_activity_id,
    'super_parent_activity' => $super_parent_activity->to_rest_response_struct,
);

###
###
###

Readonly my %DATA => (
    'actor'                    => { 'object_id' => $PERSON_SUPER_COMMENTER_ID },
    'verb'                     => 'recommend',
    'object'                   => { 'object_id' => $PERSON_OBJECT_ID },
    'super_parent_activity_id' => $super_parent_activity->get_activity_id,
    'parent_activity_id'       => $parent_activity->get_activity_id,
);

our $activity = $environment->get_activity_factory->activity_instance_from_rest_request_struct( dclone {%DATA} );
$activity->save_in_db($environment);
$activity->load( $environment, { 'rid' => $RID } );
isa_ok( $activity, $PKG );

my %expected_data_to_db_struct = (
    %DATA,
    'timebox'       => ignore,
    'activity_id'   => $activity->get_activity_id,
    'comments'      => [],
    'creation_time' => num( time, 5 ),
    'likers'        => [],
    'sources'       => [$PERSON_SUPER_COMMENTER_ID],
    'visibility'    => 1,
);
my %expected_data_to_rest_response_struct = (
    'activity_id'           => $activity->get_activity_id,
    'actor'                 => $activity->get_actor->to_rest_response_struct,
    'verb'                  => $activity->get_verb,
    'object'                => $activity->get_object->to_rest_response_struct,
    'comments'              => [],
    'creation_time'         => num( time, 5 ),
    'likers'                => [],
    'parent_activity_id'    => $parent_activity->get_activity_id,
    'super_parent_activity' => $super_parent_activity->to_rest_response_struct,
);

###
###
###

subtest 'test parent objects loaded', sub {
    cmp_deeply( $parent_activity->get_super_parent_activity, $super_parent_activity );
    cmp_deeply( $activity->get_super_parent_activity,        $super_parent_activity );
};

subtest 'test simple to_simulate_rest_struct', sub {
    cmp_deeply( $super_parent_activity->to_simulate_rest_struct, \%SUPER_PARENT_DATA );
    cmp_deeply( $parent_activity->to_simulate_rest_struct,       \%PARENT_DATA );
    cmp_deeply( $activity->to_simulate_rest_struct,              \%DATA );
};

subtest 'test simple to_db_struct', sub {
    cmp_deeply( $super_parent_activity->to_db_struct, \%expected_super_parent_data_to_db_struct );
    cmp_deeply( $parent_activity->to_db_struct,       \%expected_parent_data_to_db_struct );
    cmp_deeply( $activity->to_db_struct,              \%expected_data_to_db_struct );
};

subtest 'test simple to_rest_response_struct', sub {
    cmp_deeply( $super_parent_activity->to_rest_response_struct, \%expected_super_parent_data_to_rest_response_struct );
    cmp_deeply( $parent_activity->to_rest_response_struct,       \%expected_parent_data_to_rest_response_struct );
    cmp_deeply( $activity->to_rest_response_struct,              \%expected_data_to_rest_response_struct );
};

my $test_cb = sub {
    foreach my $act ( $super_parent_activity, $parent_activity, $activity ) {
        $act = $environment->get_activity_factory->activity_instance_from_db(
            { 'activity_id' => $act->get_activity_id } );
        $act->load( $environment, { 'rid' => $RID } );
    }

    local $Test::Builder::Level = $Test::Builder::Level + 1;

    cmp_deeply(
        $super_parent_activity->to_db_struct,
        \%expected_super_parent_data_to_db_struct,
        'cmp_deeply( $super_parent_activity->to_db_struct, \%expected_super_parent_data_to_db_struct )'
    );
    cmp_deeply(
        $parent_activity->to_db_struct,
        \%expected_parent_data_to_db_struct,
        'cmp_deeply( $parent_activity->to_db_struct,       \%expected_parent_data_to_db_struct )'
    );
    cmp_deeply(
        $activity->to_db_struct,
        \%expected_data_to_db_struct,
        'cmp_deeply( $activity->to_db_struct,              \%expected_data_to_db_struct )'
    );

    cmp_deeply( $super_parent_activity->to_rest_response_struct, \%expected_super_parent_data_to_rest_response_struct,
        'cmp_deeply( $super_parent_activity->to_rest_response_struct, \%expected_super_parent_data_to_rest_response_struct )'
    );
    cmp_deeply( $parent_activity->to_rest_response_struct, \%expected_parent_data_to_rest_response_struct,
        'cmp_deeply( $parent_activity->to_rest_response_struct,       \%expected_parent_data_to_rest_response_struct )'
    );
    cmp_deeply(
        $activity->to_rest_response_struct,
        \%expected_data_to_rest_response_struct,
        'cmp_deeply( $activity->to_rest_response_struct,              \%expected_data_to_rest_response_struct )'
    );

    my $cb = sub {
        my $data     = shift->to_rest_response_struct;
        my $activity = $environment->get_activity_factory->activity_instance_from_rest_response_struct($data);
        $activity->load( $environment, { 'rid' => $RID } );
        return $activity->to_rest_response_struct;
    };

    cmp_deeply(
        $cb->($super_parent_activity),
        \%expected_super_parent_data_to_rest_response_struct,
        'cmp_deeply( $cb->($super_parent_activity), \%expected_super_parent_data_to_rest_response_struct )'
    );
    cmp_deeply(
        $cb->($parent_activity),
        \%expected_parent_data_to_rest_response_struct,
        'cmp_deeply( $cb->($parent_activity),       \%expected_parent_data_to_rest_response_struct )'
    );
    cmp_deeply(
        $cb->($activity),
        \%expected_data_to_rest_response_struct,
        'cmp_deeply( $cb->($activity),              \%expected_data_to_rest_response_struct )'
    );
};

subtest 'test comments', sub {
    subtest 'comment on super_parent_activity', sub {
        my $comment = $super_parent_activity->save_comment( $environment,
            { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID }, 'body' => ActivityStream::Util::generate_id } );

        $super_parent_activity->save_in_db($environment);

        $comment->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'comments'} }, $comment->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'comments'} }, $comment->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'comment on parent_activity when commentable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_commentable' => sub {1} );

        my $comment = $parent_activity->save_comment( $environment,
            { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID }, 'body' => ActivityStream::Util::generate_id } );

        $comment->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'comments'} }, $comment->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'comments'} }, $comment->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'comment on parent_activity when not commentable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_commentable' => sub {0} );

        dies_ok {
            $parent_activity->save_comment( $environment,
                { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID }, 'body' => ActivityStream::Util::generate_id } );
        };

        $test_cb->();
    };

    subtest 'comment on activity when commentable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_commentable' => sub {1} );

        my $comment = $activity->save_comment( $environment,
            { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID }, 'body' => ActivityStream::Util::generate_id } );

        $comment->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'comments'} }, $comment->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'comments'} }, $comment->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'comments'} },
            $comment->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'comment on activity when not commentable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_commentable' => sub {0} );

        dies_ok {
            $activity->save_comment( $environment,
                { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID }, 'body' => ActivityStream::Util::generate_id } );
        };

        $test_cb->();
    };
};

subtest 'test likers', sub {
    subtest 'liker on super_parent_activity', sub {
        my $liker = $super_parent_activity->save_liker( $environment,
            { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID } } );

        $super_parent_activity->save_in_db($environment);

        $liker->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'likers'} }, $liker->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'likers'} }, $liker->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'liker on parent_activity when likerable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_likeable' => sub {1} );

        my $liker
              = $parent_activity->save_liker( $environment, { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID } } );

        $liker->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'likers'} }, $liker->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'likers'} }, $liker->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'liker on parent_activity when not likerable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_likeable' => sub {0} );

        dies_ok {
            $parent_activity->save_liker( $environment, { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID } } );
        };

        $test_cb->();
    };

    subtest 'liker on activity when likerable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_likeable' => sub {1} );

        my $liker = $activity->save_liker( $environment, { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID } } );

        $liker->load( $environment, { 'rid' => $RID } );

        push( @{ $expected_super_parent_data_to_db_struct{'likers'} }, $liker->to_db_struct );

        push( @{ $expected_super_parent_data_to_rest_response_struct{'likers'} }, $liker->to_rest_response_struct );
        push(
            @{ $expected_parent_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );
        push(
            @{ $expected_data_to_rest_response_struct{'super_parent_activity'}{'likers'} },
            $liker->to_rest_response_struct
        );

        $test_cb->();
    };

    subtest 'liker on activity when not likerable', sub {
        my $mock = Test::MockModule->new($PKG);
        $mock->mock( 'is_likeable' => sub {0} );

        dies_ok {
            $activity->save_liker( $environment, { 'creator' => { 'object_id' => $PERSON_COMMENTER_ID } } );
        };

        $test_cb->();
    };
};

done_testing;
