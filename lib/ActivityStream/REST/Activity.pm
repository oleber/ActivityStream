package ActivityStream::REST::Activity;
use Mojo::Base 'ActivityStream::BaseController';

use Data::Dumper;
use Readonly;

use ActivityStream::API::Activity::Friendship;
use ActivityStream::Data::CollectionFactory;
use ActivityStream::Environment;

sub post_handler_activity {
    my $self = shift;

    my $environment         = ActivityStream::Environment->new;
    my $collection_source   = $environment->get_collection_factory->collection_source;
    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $activity = ActivityStream::API::Activity::Friendship->from_rest_request_struct( $self->tx->req->json );
    $collection_activity->insert_activity( $activity->to_db_struct );

    foreach my $source ( $activity->get_sources ) {
        $collection_source->upsert_source(
            { 'source_id' => $source, 'day' => ActivityStream::Util::get_day_of(time) },
            { '$set' => { 'activity.' . $activity->get_activity_id => time } },
        );
    }

    $self->render_json( {
            'activity_id'   => $activity->get_activity_id,
            'creation_time' => $activity->get_creation_time,
        },
    );

    return;
} ## end sub post_handler_activity

sub get_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    my $environment         = ActivityStream::Environment->new;
    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $db_activity = $collection_activity->find_one_activity( { 'activity_id' => $activity_id } );

    if ( defined $db_activity ) {
        my $activity = ActivityStream::API::Activity::Friendship->from_db_struct($db_activity);

        $activity->prepare_load( $environment, { 'rid' => $rid } );
        $environment->get_async_user_agent->load_all;

        my $data = $activity->to_rest_response_struct;

        return $self->render_json( $activity->to_rest_response_struct );
    } else {
        return $self->render_json( {}, status => 404 );
    }
} ## end sub get_handler_activity

sub post_handler_user_activity_like {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $user_id     = $self->param('user_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new;
    my $activity
          = ActivityStream::API::Activity::Friendship->load_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        my $like = $activity->save_like( $environment, { 'user_id' => $user_id } );
        return $self->render_json( { 'like_id' => $like->get_like_id, 'creation_time' => $like->get_creation_time } );
    } else {
        return $self->render_json( {}, status => 404 );
    }
}


sub post_handler_user_activity_comment {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $user_id     = $self->param('user_id');
    my $body        = $self->req->json->{'body'};
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new;
    my $activity
          = ActivityStream::API::Activity::Friendship->load_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        my $comment = $activity->save_comment( $environment, { 'user_id' => $user_id, 'body' => $body } );
        return $self->render_json( { 'comment_id' => $comment->get_comment_id, 'creation_time' => $comment->get_creation_time } );
    } else {
        return $self->render_json( {}, status => 404 );
    }
}

1;
