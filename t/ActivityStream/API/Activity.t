#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Storable qw(dclone);
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );
my $async_user_agent = $environment->get_async_user_agent;

Readonly my $PKG => 'ActivityStream::API::Activity';

Readonly my $RID => ActivityStream::Util::generate_id();

use_ok($PKG);

{

    package ActivityStream::API::Activity::JustForTest;    ## no critic Modules::ProhibitMultiplePackages
    use Moose;

    extends 'ActivityStream::API::Activity';
}

## no critic TestingAndDebugging::ProhibitNoWarnings
no warnings 'redefine', 'once';

local *ActivityStream::API::ActivityFactory::_activity_structure_class = sub {
    return 'ActivityStream::API::Activity::JustForTest';
};
local *ActivityStream::API::Thing::prepare_load = sub {
    my ( $self, $args ) = @_;
    $self->set_loaded_successfully(1);
};

Readonly my %DATA => (
    'actor'  => { 'object_id' => 'xxx:123' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => 'xxx:321' },
);

{
    my $obj = $PKG->from_rest_request_struct( $environment, \%DATA );

    ok( not $obj->is_likeable );
    ok( not $obj->is_commentable );
    ok( not $obj->is_recommendable );
}

my $obj = ActivityStream::API::Activity::JustForTest->from_rest_request_struct( $environment, \%DATA );
Readonly my $ACTIVITY_ID => $obj->get_activity_id;

like( $obj->get_activity_id, qr/^\w{20}:activity$/ );

my %EXPECTED = (
    %DATA,
    'creation_time' => num( time, 5 ),
    'likers'        => [],
    'comments'      => [],
);

my %expected_db_struct = (
    %{ dclone( \%EXPECTED ) },
    'visibility' => 1,
    'sources'    => ['xxx:123'],
    'timebox'    => ignore,
);

my %expected_to_rest_response_struct = %{ dclone( \%EXPECTED ) };

{
    note('Simple activity');
    $expected_to_rest_response_struct{'activity_id'} = $expected_db_struct{'activity_id'} = $ACTIVITY_ID;

    $obj->save_in_db;
    my $activity_in_db
          = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $ACTIVITY_ID } );

    cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
    cmp_deeply( $activity_in_db->to_db_struct, $obj->to_db_struct );

    {
        note('to_rest_response_struct dies without load');
        throws_ok { $obj->to_rest_response_struct } qr/^Activity '$ACTIVITY_ID' didn't load correctly/;
        is( $obj->get_loaded_successfully, undef );
    }

    {
        note('to_rest_response_struct fail without prepare_load overwritten and loaded_successfully set');
        $obj->set_loaded_successfully(0);
        $obj->load( { 'rid' => $RID } );
        throws_ok( sub { $obj->to_rest_response_struct }, qr/^Activity '$ACTIVITY_ID' didn't load correctly/ );
    }

    {
        note('the load and internaly the prepare_load defaults the loaded_successfully to a true value');
        $obj->set_loaded_successfully(undef);
        $obj->load( { 'rid' => $RID } );
        lives_ok( sub { $obj->to_rest_response_struct } );
        ok( $obj->get_loaded_successfully );
    }

    {
        note('to_rest_response_struct success with prepare_load overwritten and loaded_successfully set');

        package ActivityStream::API::Activity::JustForTest;    ## no critic Modules::ProhibitMultiplePackages
        local *ActivityStream::API::Activity::JustForTest::prepare_load = sub {
            my ( $self, $environment, $args ) = @_;
            $self->set_loaded_successfully(1);
            $self->SUPER::prepare_load($args);
        };

        $obj->load( { 'rid' => $RID } );
        $activity_in_db->load( { 'rid' => $RID } );

        main::cmp_deeply( $obj->to_rest_response_struct,            \%expected_to_rest_response_struct );
        main::cmp_deeply( $activity_in_db->to_rest_response_struct, $obj->to_rest_response_struct );
    }
}

{

    package ActivityStream::API::Activity::JustForTest;    ## no critic Modules::ProhibitMultiplePackages
    *prepare_load = sub {
        my ( $self, $environment, $args ) = @_;
        $self->SUPER::prepare_load($args);
        $self->set_loaded_successfully(1);
    };
}

sub test_db_status {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $activity_in_db
          = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $ACTIVITY_ID } );

    cmp_deeply( $obj->to_db_struct,            \%expected_db_struct, 'Check $obj to_db_struct' );
    cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

    $obj->load( { 'rid' => $RID } );
    $activity_in_db->load( { 'rid' => $RID } );

    cmp_deeply(
        $obj->to_rest_response_struct,
        \%expected_to_rest_response_struct,
        'Check $obj to_rest_response_struct'
    );

    cmp_deeply(
        $activity_in_db->to_rest_response_struct,
        \%expected_to_rest_response_struct,
        'Check $activity_in_db to_rest_response_struct'
    );

    return;
} ## end sub test_db_status

done_testing;
