#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Storable qw(dclone);
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;
use ActivityStream::Util;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );
my $async_user_agent = $environment->get_async_user_agent;

Readonly my $PKG => 'ActivityStream::API::Activity';

Readonly my $USER_1_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( '%s:person', ActivityStream::Util::generate_id );

Readonly my $RID => ActivityStream::Util::generate_id();

use_ok($PKG);

{

    package ActivityStream::API::Activity_Likers::JustForTest;
    use Moose;

    extends 'ActivityStream::API::Activity';

    sub prepare_load {
        my ( $self, $environment, $args ) = @_;
        $self->SUPER::prepare_load( $environment, $args );
        $self->set_loaded_successfully(1);

        return;
    }
}

no warnings 'redefine', 'once';

local *ActivityStream::API::ActivityFactory::_activity_structure_class = sub {
    return 'ActivityStream::API::Activity_Likers::JustForTest';
};
local *ActivityStream::API::Object::prepare_load = sub {
    my ( $self, $environment, $args ) = @_;
    $self->set_loaded_successfully(1);
};

Readonly my %DATA => (
    'actor'  => { 'object_id' => '123:xxx' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => '321:xxx' },
);

my $obj = ActivityStream::API::Activity_Likers::JustForTest->from_rest_request_struct( \%DATA );
Readonly my $ACTIVITY_ID => $obj->get_activity_id;

like( $obj->get_activity_id, qr/^\w{20}:activity$/ );

my %EXPECTED = (
    %DATA,
    'activity_id'   => $ACTIVITY_ID,
    'creation_time' => num( time, 5 ),
    'likers'        => [],
    'comments'      => [],
);

my %expected_db_struct = ( %{ dclone( \%EXPECTED ) }, 'visibility' => 1, 'timebox' => ignore, );
my %expected_to_rest_response_struct = %{ dclone( \%EXPECTED ) };

sub test_db_status {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $activity_in_db
          = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $ACTIVITY_ID } );

    cmp_deeply( $obj->to_db_struct,            \%expected_db_struct, 'Check $obj to_db_struct' );
    cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

    $obj->load( $environment, { 'rid' => $RID } );
    $activity_in_db->load( $environment, { 'rid' => $RID } );

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

foreach my $person_id ( $USER_1_ID, $USER_2_ID, $USER_3_ID ) {
    my $person = ActivityStream::API::Object::Person->new( 'object_id' => $person_id );
    $t->app->routes->get( $person->create_request( $environment, { 'rid' => $RID } ) )
          ->to( 'cb' => $person->create_test_response( { 'first_name' => "first name $person_id", 'rid' => $RID } ) );
}

$obj->save_in_db($environment);
$obj->load( $environment, { 'rid' => $RID } );

{
    note('test likers');

    {
        note('like a not likeable activity');

        {
            my $activity_in_db_before_like = $environment->get_activity_factory->activity_instance_from_db( 
                { 'activity_id' => $ACTIVITY_ID } );

            dies_ok { $obj->save_liker( $environment, {'creator' => { 'object_id' => $USER_1_ID } } ) };

            my $activity_in_db_after_like = $environment->get_activity_factory->activity_instance_from_db( 
                { 'activity_id' => $ACTIVITY_ID } );

            cmp_deeply( $activity_in_db_before_like, $activity_in_db_after_like );
            is( $obj->get_loaded_successfully, undef, 'Save like cleans loaded_successfully' );
        }

        $obj->load( $environment, { 'rid' => $RID } );
        is( $obj->get_loaded_successfully, 1 );

        cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
        cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );

        $obj->save_in_db($environment);

        test_db_status;
    }

    {
        {

            package ActivityStream::API::Activity_Likers::JustForTest;
            *is_likeable = sub { return 1 };
        }

        {
            note('like a likeable activity');

            my $like = $obj->save_liker( $environment, { 'creator' => { 'object_id' => $USER_1_ID } } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_1_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_db_struct,
                    'creation_time' => $like->get_creation_time,
                } );

            push(
                @{ $expected_to_rest_response_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_rest_response_struct,
                    'load'          => 'SUCCESS',
                    'creation_time' => $like->get_creation_time,
                } );

            is( $obj->get_loaded_successfully, undef, 'Save like cleans loaded_successfully' );

            test_db_status;
        }

        {
            note('second like a likeable activity');

            my $like = $obj->save_liker( $environment, { 'creator' => { 'object_id' => $USER_2_ID }, } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_2_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_db_struct,
                    'creation_time' => $like->get_creation_time,
                } );

            push(
                @{ $expected_to_rest_response_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_rest_response_struct,
                    'load'          => 'SUCCESS',
                    'creation_time' => $like->get_creation_time,
                } );

            is( $obj->get_loaded_successfully, undef, 'Save like cleans loaded_successfully' );

            test_db_status;
        }

        {
            note('third like a likeable activity');

            my $like = $obj->save_liker( $environment, {'creator' => { 'object_id' => $USER_3_ID }, } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_3_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_db_struct,
                    'creation_time' => $like->get_creation_time,
                } );

            push(
                @{ $expected_to_rest_response_struct{'likers'} },
                {
                    'like_id'       => $like->get_like_id,
                    'creator'       => $object_person->to_rest_response_struct,
                    'load'          => 'SUCCESS',
                    'creation_time' => $like->get_creation_time,
                } );

            is( $obj->get_loaded_successfully, undef, 'Save like cleans loaded_successfully' );

            test_db_status;
        }
    }
}

{
    note('limite load of part of the likers users');

    {
        note('max_likers = 0 show all');

        my $activity_in_db = $environment->get_activity_factory->activity_instance_from_db( 
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 0 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_likers = 1');

        my $activity_in_db = $environment->get_activity_factory->activity_instance_from_db( 
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 1 } );

        my %comment_0 = %{ $expected_to_rest_response_struct{'likers'}[0] };
        my %comment_1 = %{ $expected_to_rest_response_struct{'likers'}[1] };

        delete $comment_0{'creator'};
        delete $comment_1{'creator'};

        local $expected_to_rest_response_struct{'likers'} = [
            +{ %comment_0, 'load' => 'NOT_REQUESTED' },
            +{ %comment_1, 'load' => 'NOT_REQUESTED' },
            $expected_to_rest_response_struct{'likers'}[2],
        ];

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_likers = 2');

        my $activity_in_db = $environment->get_activity_factory->activity_instance_from_db( 
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 2 } );

        my %comment_0 = %{ $expected_to_rest_response_struct{'likers'}[0] };
        delete $comment_0{'creator'};

        local $expected_to_rest_response_struct{'likers'} = [
            +{ %comment_0, 'load' => 'NOT_REQUESTED' }, $expected_to_rest_response_struct{'likers'}[1],
            $expected_to_rest_response_struct{'likers'}[2],
        ];

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_likers = 3');

        my $activity_in_db = $environment->get_activity_factory->activity_instance_from_db( 
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 3 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_likers = 4');

        my $activity_in_db = $environment->get_activity_factory->activity_instance_from_db( 
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 4 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }
}

{
    note("Fail user load");

    my $user_2_request
          = ActivityStream::API::Object::Person->new( 'object_id' => $USER_2_ID )->create_request( $environment, { 'rid' => $RID } );
    my $previous_response = $async_user_agent->get_response_to($user_2_request);
    $async_user_agent->put_response_to( "GET $user_2_request",
        Mojo::Transaction::HTTP->new( res => Mojo::Message::Response->new( code => 403 ) ) );

    my $activity_in_db
          = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $ACTIVITY_ID } );

    cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

    $activity_in_db->load( $environment, { 'rid' => $RID, 'max_likers' => 2 } );

    my %liker_0 = %{ $expected_to_rest_response_struct{'likers'}[0] };
    delete $liker_0{'creator'};

    my %liker_1 = %{ $expected_to_rest_response_struct{'likers'}[1] };
    delete $liker_1{'creator'};

    local $expected_to_rest_response_struct{'likers'} = [
        +{ %liker_0, 'load' => 'NOT_REQUESTED' },
        +{ %liker_1, 'load' => 'FAIL_LOAD' },
        $expected_to_rest_response_struct{'likers'}[2],
    ];

    cmp_deeply(
        $activity_in_db->to_rest_response_struct,
        \%expected_to_rest_response_struct,
        'Check $obj to_rest_response_struct'
    );

    $async_user_agent->put_response_to( "GET $user_2_request", $previous_response );
}

{
    note('remove likers');

    {
        note('delete not existing liker');
        throws_ok(
            sub { $obj->delete_liker( $environment, { 'like_id' => 'not existing' } ) },
            'ActivityStream::X::LikerNotFound',
        );
        test_db_status;
    }

    {
        note('delete first existing liker');
        $obj->delete_liker( $environment, { 'like_id' => $expected_to_rest_response_struct{'likers'}[1]{'like_id'} }, );

        $expected_db_struct{'likers'} = [ $expected_db_struct{'likers'}[0], $expected_db_struct{'likers'}[2] ];
        $expected_to_rest_response_struct{'likers'}
              = [ $expected_to_rest_response_struct{'likers'}[0], $expected_to_rest_response_struct{'likers'}[2] ];
        test_db_status;
    }

    {
        note('delete second existing liker');
        $obj->delete_liker( $environment, { 'like_id' => $expected_to_rest_response_struct{'likers'}[0]{'like_id'} }, );

        $expected_db_struct{'likers'}               = [ $expected_db_struct{'likers'}[1] ];
        $expected_to_rest_response_struct{'likers'} = [ $expected_to_rest_response_struct{'likers'}[1] ];
        test_db_status;
    }

    {
        note('delete first existing liker');
        $obj->delete_liker( $environment, { 'like_id' => $expected_to_rest_response_struct{'likers'}[0]{'like_id'} }, );

        $expected_db_struct{'likers'}               = [];
        $expected_to_rest_response_struct{'likers'} = [];
        test_db_status;
    }
}

done_testing;
