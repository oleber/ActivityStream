#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Readonly;
use Test::MockModule;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );
my $async_user_agent = $environment->get_async_user_agent;

Readonly my $PKG => 'ActivityStream::API::Activity';

use_ok($PKG);

{

    package ActivityStream::API::Activity_Recommendation::TestActivity;
    use Moose;
    extends 'ActivityStream::API::Activity';
}

my $mock_activity_factory = Test::MockModule->new('ActivityStream::API::ActivityFactory');
$mock_activity_factory->mock(
    '_activity_structure_class' => sub {
        return 'ActivityStream::API::Activity_Recommendation::TestActivity';
    } );

Readonly my %DATA => (
    'actor'  => { 'object_id' => '123:xxx' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => '321:xxx' },
);

my $activity
      = ActivityStream::API::Activity_Recommendation::TestActivity->from_rest_request_struct( $environment, \%DATA );
$activity->save_in_db;

Readonly my $ACTIVITY_ID => $activity->get_activity_id;
Readonly my $BODY        => ActivityStream::Util::generate_id;
Readonly my $PERSON_ID   => sprintf( '%s:person', ActivityStream::Util::generate_id );

subtest 'Test is Recommendable', sub {

    my @callbacks;

    my $mock_thing = Test::MockModule->new('ActivityStream::API::Thing');
    $mock_thing->mock(
        'save_recommendation' => sub {
            my ( $self, @param ) = @_;
            push( @callbacks, [ 'save_recommendation' => @_ ] );
            $mock_thing->original('save_recommendation')->( $self, @param );
        } );

    subtest '', sub {

        subtest '', sub {
            @callbacks = ();
            $mock_thing->mock( 'is_recommendable' => sub {1} );

            ok $activity->is_recommendable;

            lives_ok {
                $activity->save_recommendation( { 'creator' => { 'object_id' => $PERSON_ID }, 'body' => $BODY } );
            };

            cmp_deeply(
                \@callbacks,
                [ [
                        'save_recommendation' => $activity->get_object,
                        $activity, { 'creator' => { 'object_id' => $PERSON_ID }, 'body' => $BODY } ]
                ],
            );
        };

        subtest '', sub {
            @callbacks = ();
            $mock_thing->mock( 'is_recommendable' => sub {0} );

            ok not $activity->is_recommendable;

            throws_ok(
                sub {
                    $activity->save_recommendation( { 'creator' => { 'object_id' => $PERSON_ID }, 'body' => $BODY } );
                },
                qr/\Q@{[ sprintf( q(Activity %s isn't recommendable), $activity->get_activity_id ) ]}\E/
            );
            cmp_deeply( \@callbacks, [] );
        };
    };

    subtest '', sub {
        my $mock_activity = Test::MockModule->new('ActivityStream::API::Activity');
        $mock_activity->mock( 'get_recommendable_thing' => sub {return} );

        subtest '', sub {
            @callbacks = ();
            $mock_thing->mock( 'is_recommendable' => sub {1} );

            ok not $activity->is_recommendable;

            throws_ok(
                sub {
                    $activity->save_recommendation( { 'creator' => { 'object_id' => $PERSON_ID }, 'body' => $BODY } );
                },
                qr/\Q@{[ sprintf( q(Activity %s isn't recommendable), $activity->get_activity_id ) ]}\E/
            );
            cmp_deeply( \@callbacks, [] );
        };

        subtest '', sub {
            @callbacks = ();
            $mock_thing->mock( 'is_recommendable' => sub {0} );

            ok not $activity->is_recommendable;

            throws_ok(
                sub {
                    $activity->save_recommendation( { 'creator' => { 'object_id' => $PERSON_ID }, 'body' => $BODY } );
                },
                qr/\Q@{[ sprintf( q(Activity %s isn't recommendable), $activity->get_activity_id ) ]}\E/
            );
            cmp_deeply( \@callbacks, [] );
        };
    };
};

done_testing;
