package ActivityStream::REST::Activity;
use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use HTTP::Status qw(:constants);
use List::Util qw(min first);
use List::MoreUtils qw(any);
use Readonly;

use ActivityStream::API::ActivityFactory;
use ActivityStream::API::Search;
use ActivityStream::Environment;
use ActivityStream::REST::Constants;

sub post_handler_activity {
    my $self = shift;

    my $rid = $self->param('rid');

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_NO_RID_DEFINED },
        'status' => HTTP_FORBIDDEN )
          if not defined $rid;

    my $environment = ActivityStream::Environment->new;

    my $activity = ActivityStream::API::ActivityFactory->instance_from_rest_request_struct( $self->tx->req->json );

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
        'status' => HTTP_FORBIDDEN )
          if not any { $rid eq $_ } ( 'internal', $activity->get_sources );

    $activity->save_in_db($environment);

    $self->render_json( {
            'activity_id'   => $activity->get_activity_id,
            'creation_time' => $activity->get_creation_time,
        },
    );

    return;
} ## end sub post_handler_activity

sub delete_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_NO_RID_DEFINED },
        'status' => HTTP_FORBIDDEN )
          if not defined $rid;

    my $environment = ActivityStream::Environment->new;

    my $activity
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
            'status' => HTTP_FORBIDDEN )
              if not any { $rid eq $_ } ( 'internal', $activity->get_sources );

        $activity->save_visibility( $environment, 0 );

        return $self->render_json( {} );
    } else {
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
} ## end sub delete_handler_activity

sub get_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new;

    my $activity
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

    if ( defined($activity) and $activity->get_visibility ) {
        $activity->load( $environment, { 'rid' => $rid } );
        return $self->render_json( $activity->to_rest_response_struct );
    } else {
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
}

sub get_handler_user_activitystream {
    my $self = shift;

    my $user_id           = $self->param('user_id');
    my @see_sources       = $self->param('see_sources');
    my @ignore_sources    = $self->param('ignore_sources');
    my @ignore_activities = $self->param('ignore_activities');
    my $limit             = $self->param('limit');
    my $rid               = $self->param('rid');

    my $environment = ActivityStream::Environment->new;

    my $filter = ActivityStream::API::Search::Filter->new( {
            'user'              => $user_id,
            'see_sources'       => \@see_sources,
            'ignore_sources'    => \@ignore_sources,
            'ignore_activities' => \@ignore_activities,
            'limit'             => ( $limit // 25 ),
    } );

    my $search = ActivityStream::API::Search->search( $environment, $filter );

    my @activities;
    while ( my $activity = $search->next_activity ) {
        next if not $activity->preload_filter_pass($filter);

        $activity->prepare_load( $environment, { 'rid' => $rid } );

        push( @activities, $activity );
        last if @activities >= $filter->get_limit;
    }

    $environment->get_async_user_agent->load_all;

    return $self->render_json( { 'activities' => [ map { $_->to_rest_response_struct } @activities ] } );
} ## end sub get_handler_user_activitystream

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
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
}

sub delete_handler_activity_like {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $like_id     = $self->param('like_id');
    my $rid         = $self->param('rid');

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_NO_RID_DEFINED },
        'status' => HTTP_FORBIDDEN )
          if not defined $rid;

    my $environment = ActivityStream::Environment->new;

    my $activity
          = ActivityStream::API::ActivityFactory->instance_from_db( $environment, { 'activity_id' => $activity_id } );

    my $activity_like = first { $like_id eq $_->get_like_id } @{ $activity->get_likers };
    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_LIKE_NOT_FOUND },
        'status' => HTTP_NOT_FOUND )
          if not defined $activity_like;

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
        'status' => HTTP_FORBIDDEN )
          if not any { $rid eq $_ } ( 'internal', $activity_like->get_user_id );

    $activity->delete_liker( $environment, { 'like_id' => $like_id } );

    return $self->render_json( {} );
} ## end sub delete_handler_activity_like

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
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
} ## end sub post_handler_user_activity_comment

1;
