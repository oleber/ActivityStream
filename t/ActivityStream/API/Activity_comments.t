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

Readonly my $environment => ActivityStream::Environment->new;
my $async_user_agent = $environment->get_async_user_agent;

Readonly my $PKG => 'ActivityStream::API::Activity';

Readonly my $USER_1_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( "person:%s", ActivityStream::Util::generate_id );

Readonly my $RID => ActivityStream::Util::generate_id();

use_ok($PKG);

{

    package ActivityStream::API::Activity_Comments::JustForTest;
    use Moose;

    extends 'ActivityStream::API::Activity';

    sub prepare_load {
        my ( $self, $environment, $args ) = @_;
        $self->SUPER::prepare_load( $environment, $args );
        $self->set_loaded_successfully(1);
    }
}

no warnings 'redefine', 'once';

local *ActivityStream::API::ActivityFactory::_structure_class = sub {
    return 'ActivityStream::API::Activity_Comments::JustForTest';
};
local *ActivityStream::API::Object::prepare_load = sub {
    my ( $self, $environment, $args ) = @_;
    $self->set_loaded_successfully(1);
};

Readonly my %DATA => (
    'actor'  => { 'object_id' => 'xxx:123' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => 'xxx:321' },
);

my $obj = ActivityStream::API::Activity_Comments::JustForTest->from_rest_request_struct( \%DATA );
Readonly my $ACTIVITY_ID => $obj->get_activity_id;

like( $obj->get_activity_id, qr/^activity:\w{20}$/ );

my %EXPECTED = (
    %DATA,
    'activity_id'   => $ACTIVITY_ID,
    'creation_time' => num( time, 5 ),
    'likers'        => {},
    'comments'      => [],
);

my %expected_db_struct = ( %{ dclone( \%EXPECTED ) }, 'visibility' => 1, );
my %expected_to_rest_response_struct = %{ dclone( \%EXPECTED ) };

sub test_db_status {
    local $Test::Builder::Level = $Test::Builder::Level + 1;

    my $activity_in_db
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $ACTIVITY_ID } );

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

} ## end sub test_db_status

foreach my $person_id ( $USER_1_ID, $USER_2_ID, $USER_3_ID ) {
    my $user_request = $async_user_agent->create_request_person( { 'object_id' => $person_id, 'rid' => $RID } );
    $async_user_agent->put_response_to( $user_request->as_string,
        $async_user_agent->create_test_response_person( { 'first_name' => "first name $person_id", 'rid' => $RID } ),
    );
}

$obj->save_in_db($environment);
$obj->load( $environment, { 'rid' => $RID } );

Readonly my $BODY_1 => ActivityStream::Util::generate_id;
Readonly my $BODY_2 => ActivityStream::Util::generate_id;
Readonly my $BODY_3 => ActivityStream::Util::generate_id;

{
    note('Save a comment');

    {
        note('comment a not commentable activity');

        {
            my $activity_in_db_before_like = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                { 'activity_id' => $ACTIVITY_ID } );

            dies_ok { $obj->save_comment( $environment, { user_id => $USER_1_ID, 'body' => $BODY_1 } ) };

            my $activity_in_db_after_like = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
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

            package ActivityStream::API::Activity_Comments::JustForTest;
            *is_commentable = sub { return 1 };
        }

        {
            note('comment a commentable activity');

            my $comment = $obj->save_comment( $environment, { user_id => $USER_1_ID, 'body' => $BODY_1 } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_1_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_1_ID,
                    'body'          => $BODY_1,
                    'creation_time' => $comment->get_creation_time,
                } );
            push(
                @{ $expected_to_rest_response_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_1_ID,
                    'user'          => $object_person->to_rest_response_struct,
                    'body'          => $BODY_1,
                    'creation_time' => $comment->get_creation_time,
                    'load'          => 'success',
                } );

            test_db_status;
        }

        {
            note('second comment a commentable activity');

            my $comment = $obj->save_comment( $environment, { user_id => $USER_2_ID, 'body' => $BODY_2 } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_2_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_2_ID,
                    'body'          => $BODY_2,
                    'creation_time' => $comment->get_creation_time,
                } );
            push(
                @{ $expected_to_rest_response_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_2_ID,
                    'user'          => $object_person->to_rest_response_struct,
                    'body'          => $BODY_2,
                    'creation_time' => $comment->get_creation_time,
                    'load'          => 'success',
                } );

            test_db_status;
        }

        {
            note('third comment a commentable activity');

            my $comment = $obj->save_comment( $environment, { 'user_id' => $USER_3_ID, 'body' => $BODY_3 } );

            my $object_person = ActivityStream::API::Object::Person->new( { 'object_id' => $USER_3_ID } );
            $object_person->load( $environment, { 'rid' => $RID } );

            push(
                @{ $expected_db_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_3_ID,
                    'body'          => $BODY_3,
                    'creation_time' => $comment->get_creation_time,
                } );
            push(
                @{ $expected_to_rest_response_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_3_ID,
                    'user'          => $object_person->to_rest_response_struct,
                    'body'          => $BODY_3,
                    'creation_time' => $comment->get_creation_time,
                    'load'          => 'success',
                } );

            test_db_status;
        }
    }
}

{
    note('limite load of part of the comment users');

    {
        note('max_comments = 0 show all');

        my $activity_in_db = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_comments' => 0 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_comments = 1');

        my $activity_in_db = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_comments' => 1 } );

        my %comment_0 = %{$expected_to_rest_response_struct{'comments'}[0]};
        my %comment_1 = %{$expected_to_rest_response_struct{'comments'}[1]};

        delete $comment_0{'user'};
        delete $comment_1{'user'};

        local $expected_to_rest_response_struct{'comments'} = [
            { %comment_0, 'load' => 'not requested' },
            { %comment_1, 'load' => 'not requested' },
            $expected_to_rest_response_struct{'comments'}[2],
        ];

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_comments = 2');

        my $activity_in_db = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_comments' => 2 } );

        my %comment_0 = %{$expected_to_rest_response_struct{'comments'}[0]};
        delete $comment_0{'user'};

        local $expected_to_rest_response_struct{'comments'} = [
            { %comment_0, 'load' => 'not requested' },
            $expected_to_rest_response_struct{'comments'}[1],
            $expected_to_rest_response_struct{'comments'}[2],
        ];

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_comments = 3');

        my $activity_in_db = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_comments' => 3 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }

    {
        note('max_comments = 4');

        my $activity_in_db = ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $ACTIVITY_ID } );
        cmp_deeply( $activity_in_db->to_db_struct, \%expected_db_struct, 'Check $activity_in_db to_db_struct' );

        $activity_in_db->load( $environment, { 'rid' => $RID, 'max_comments' => 4 } );

        cmp_deeply(
            $activity_in_db->to_rest_response_struct,
            \%expected_to_rest_response_struct,
            'Check $obj to_rest_response_struct'
        );
    }
}

done_testing();
