package ActivityStream::REST::Activity;
use Mojo::Base 'ActivityStream::BaseController';

use Data::Dumper;
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;

sub post_handler_activity {
    my $self = shift;

    my $activity = ActivityStream::API::ActivityFactory->instance_from_rest_request_struct( $self->tx->req->json );
    $activity->save_in_db( ActivityStream::Environment->new );

    $self->render_json( {
            'activity_id'   => $activity->get_activity_id,
            'creation_time' => $activity->get_creation_time,
        },
    );

    return;
}

sub get_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new;

    my $activity
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        $activity->load( $environment, { 'rid' => $rid } );
        return $self->render_json( $activity->to_rest_response_struct );
    } else {
        return $self->render_json( {}, status => 404 );
    }
}

sub post_handler_user_activity_like {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $user_id     = $self->param('user_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new;

    my $activity
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

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
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        my $comment = $activity->save_comment( $environment, { 'user_id' => $user_id, 'body' => $body } );
        return $self->render_json( {
                'comment_id'    => $comment->get_comment_id,
                'creation_time' => $comment->get_creation_time,
        } );
    } else {
        return $self->render_json( {}, status => 404 );
    }
} ## end sub post_handler_user_activity_comment

1;
