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

Readonly my $PKG => 'ActivityStream::API::Activity';

Readonly my $USER_1_ID => sprintf( "x:person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_2_ID => sprintf( "x:person:%s", ActivityStream::Util::generate_id );
Readonly my $USER_3_ID => sprintf( "x:person:%s", ActivityStream::Util::generate_id );

use_ok($PKG);

{
    package ActivityStream::API::Activity::JustForTest;
    use Moose;

    extends 'ActivityStream::API::Activity';
}

no warnings 'redefine';
local *ActivityStream::API::ActivityFactory::_structure_class = sub {
    return 'ActivityStream::API::Activity::JustForTest';
};

Readonly my %DATA => (
    'actor'  => { 'object_id' => 'x:xxx:123' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => 'x:xxx:321' },
);

{
    my $obj = $PKG->from_rest_request_struct( \%DATA );

    ok( not $obj->is_likeable );
    ok( not $obj->is_commentable );
    ok( not $obj->is_recomendable );
}

my $obj = $PKG->from_rest_request_struct( \%DATA );

my %EXPECTED = (
    %DATA,
    'creation_time' => num( time, 5 ),
    'likers'        => {},
    'comments'      => [],
);

my %expected_db_struct = (
    %{dclone(\%EXPECTED)},
    'visibility' => 1,
);

my %expected_to_rest_response_struct = %{dclone(\%EXPECTED)};

$obj->set_loaded_successfully(1);
$obj->get_actor->set_loaded_successfully(1);
$obj->get_object->set_loaded_successfully(1);

{
    note('Simple activity');
    $expected_to_rest_response_struct{'activity_id'} = $expected_db_struct{'activity_id'} = $obj->get_activity_id;
    cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
    cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
    $obj->save_in_db($environment);
    cmp_deeply(
        ActivityStream::API::ActivityFactory->instance_from_db( $environment,
            { 'activity_id' => $obj->get_activity_id },
              )->to_db_struct,
        $obj->to_db_struct,
    );
}

{
    note('test likes');

    {
        note('like a not likeable activity');
        dies_ok { $obj->save_like( $environment, { user_id => $USER_1_ID } ) };
        cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
        cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
        $obj->save_in_db($environment);
        cmp_deeply(
            ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                { 'activity_id' => $obj->get_activity_id },
                  )->to_db_struct,
            $obj->to_db_struct,
        );
    }

    {
        no strict 'refs';
        no warnings 'redefine';
        local *{ sprintf( '%s::is_likeable', $PKG ) } = sub { return 1 };

        {
            note('like a likeable activity');
            my $like = $obj->save_like( $environment, { user_id => $USER_1_ID } );
            $expected_to_rest_response_struct{'likers'}{$USER_1_ID} = $expected_db_struct{'likers'}{$USER_1_ID} = {
                'like_id'       => $like->get_like_id,
                'user_id'       => $USER_1_ID,
                'creation_time' => $like->get_creation_time,
            };
            cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
            cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
            cmp_deeply(
                ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                    { 'activity_id' => $obj->get_activity_id } )->to_db_struct,
                $obj->to_db_struct,
            );
        }

        {
            note('second like a likeable activity');

            my $like = $obj->save_like( $environment, { user_id => $USER_2_ID } );
            $expected_to_rest_response_struct{'likers'}{$USER_2_ID} =  $expected_db_struct{'likers'}{$USER_2_ID} = {
                'like_id'       => $like->get_like_id,
                'user_id'       => $USER_2_ID,
                'creation_time' => $like->get_creation_time,
            };
            cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
            cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
            cmp_deeply(
                ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                    { 'activity_id' => $obj->get_activity_id } )->to_db_struct,
                $obj->to_db_struct,
            );
        }
    }
}

{
    note('test comments');

    Readonly my $BODY_1 => ActivityStream::Util::generate_id;
    Readonly my $BODY_2 => ActivityStream::Util::generate_id;

    {
        note('comment a not commentable activity');
        dies_ok { $obj->save_comment( $environment, { user_id => $USER_1_ID, 'body' => $BODY_1 } ) };
        cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
        cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
        $obj->save_in_db($environment);
        cmp_deeply(
            ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                { 'activity_id' => $obj->get_activity_id } )->to_db_struct,
            $obj->to_db_struct,
        );
    }

    {
        no strict 'refs';
        no warnings 'redefine';
        local *{ sprintf( '%s::is_commentable', $PKG ) } = sub { return 1 };

        {
            note('comment a commentable activity');
            my $comment = $obj->save_comment( $environment, { user_id => $USER_1_ID, 'body' => $BODY_1 } );
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
                    'body'          => $BODY_1,
                    'creation_time' => $comment->get_creation_time,
                } );
            cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
            cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
            cmp_deeply(
                ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                    { 'activity_id' => $obj->get_activity_id } )->to_db_struct,
                $obj->to_db_struct,
            );
        }

        {
            note('second comment a commentable activity');

            my $comment = $obj->save_comment( $environment, { user_id => $USER_2_ID,, 'body' => $BODY_2 } );
            push(
                @{ $expected_to_rest_response_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_2_ID,
                    'body'          => $BODY_2,
                    'creation_time' => $comment->get_creation_time,
                } );
            push(
                @{ $expected_db_struct{'comments'} },
                {
                    'comment_id'    => $comment->get_comment_id,
                    'user_id'       => $USER_2_ID,
                    'body'          => $BODY_2,
                    'creation_time' => $comment->get_creation_time,
                } );
            cmp_deeply( $obj->to_db_struct,            \%expected_db_struct );
            cmp_deeply( $obj->to_rest_response_struct, \%expected_to_rest_response_struct );
            cmp_deeply(
                ActivityStream::API::ActivityFactory->instance_from_db( $environment,
                    { 'activity_id' => $obj->get_activity_id } )->to_db_struct,
                $obj->to_db_struct,
            );
        }
    }
}

done_testing();
