package ActivityStream::REST::Activity;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Data::Dumper;
use HTTP::Status qw( :constants );
use List::Util qw(first);
use List::MoreUtils qw(any);

use ActivityStream::API::ActivityFactory;
use ActivityStream::API::Search;
use ActivityStream::API::Search::Filter;
use ActivityStream::Environment;
use ActivityStream::REST::Constants;

sub post_handler_activity {
    my $self = shift;

    my $rid = $self->param('rid');

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_NO_RID_DEFINED },
        'status' => HTTP_FORBIDDEN )
          if not defined $rid;

    my $environment = ActivityStream::Environment->new( controller => $self );

    $self->app->log->debug("Creating activity: " . $self->tx->req->body);

    my $activity
          = $environment->get_activity_factory->activity_instance_from_rest_request_struct( $self->tx->req->json );

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
        'status' => HTTP_FORBIDDEN )
          if not any { $rid eq $_ } ( 'internal', $activity->get_sources );

    $activity->save_in_db;

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

    my $environment = ActivityStream::Environment->new( controller => $self );
    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );

    if ( defined $activity ) {
        if ( not any { $rid eq $_ } ( 'internal', $activity->get_sources ) ) {

            warn "expecting RID ($rid) in @{['internal', $activity->get_sources]}";

            return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
                'status' => HTTP_FORBIDDEN );
        }

        $activity->save_visibility( 0 );

        return $self->render_json( {} );
    } else {
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
} ## end sub delete_handler_activity

sub get_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );

    if ( defined($activity) and $activity->get_visibility ) {
        $activity->prepare_load(  { 'rid' => $rid } );

        $environment->get_async_user_agent->load_all(
            sub {
                $self->render_json( $activity->to_rest_response_struct );

                #TODO: fail on activity load error
            } );

        $self->render_later;

        return;
    } else {
        return $self->render_json( {}, 'status' => HTTP_NOT_FOUND );
    }
} ## end sub get_handler_activity

sub get_handler_user_activitystream {
    my $self = shift;

    my $user_id = $self->param('user_id');

    my @see_source_ids    = $self->param('see_source_id');
    my @ignore_source_ids = $self->param('ignore_source_id');
    my @ignore_activities = $self->param('ignore_activity');

    my $limit = $self->param('limit');
    my $rid   = $self->param('rid');

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $filter = ActivityStream::API::Search::Filter->new( {
            'consumer_id'       => $user_id,
            'see_source_ids'    => \@see_source_ids,
            'ignore_source_ids' => \@ignore_source_ids,
            'ignore_activities' => \@ignore_activities,
            'limit'             => ( $limit // 25 ),
    } );

    my $search = ActivityStream::API::Search->search( $environment, $filter );

    my @activities;
    while ( my $activity = $search->next_activity ) {
        next if not $activity->preload_filter_pass($filter);

        $activity->prepare_load(  { 'rid' => $rid } );

        push( @activities, $activity );
        last if @activities >= $filter->get_limit;
    }

    $environment->get_async_user_agent->load_all(
        sub {
            $self->render_json( { 'activities' => [ map { $_->to_rest_response_struct } @activities ] } );
        } );

    $self->render_later;

    return;
} ## end sub get_handler_user_activitystream

sub post_handler_user_activity_like {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $user_id     = $self->param('user_id');
    my $rid         = $self->param('rid');

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );
    return $self->render_json( {}, 'status' => HTTP_NOT_FOUND ) if not defined $activity;

    my $like = $activity->save_liker(  { 'creator' => { 'object_id' => $user_id } } );
    return $self->render_json( { 'like_id' => $like->get_like_id, 'creation_time' => $like->get_creation_time } );
}

sub delete_handler_activity_like {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $like_id     = $self->param('like_id');
    my $rid         = $self->param('rid');

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_NO_RID_DEFINED },
        'status' => HTTP_FORBIDDEN )
          if not defined $rid;

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );

    my $activity_like = first { $like_id eq $_->get_like_id } @{ $activity->get_likers };
    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_LIKE_NOT_FOUND },
        'status' => HTTP_NOT_FOUND )
          if not defined $activity_like;

    return $self->render_json( { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_BAD_RID },
        'status' => HTTP_FORBIDDEN )
          if not any { $rid eq $_ } ( 'internal', $activity_like->get_creator->get_object_id );

    $activity->delete_liker({ 'like_id' => $like_id } );
    return $self->render_json( {} );
} ## end sub delete_handler_activity_like

sub post_handler_user_activity_comment {
    my $self = shift;

    my $user_id = $self->param('user_id');

    my $rid = $self->param('rid') || $self->req->json->{'rid'};
    return $self->render_json( {}, 'status' => HTTP_FORBIDDEN ) if not( $rid ~~ [ $user_id, 'internal' ] );

    my $activity_id = $self->param('activity_id');
    my $body        = $self->req->json->{'body'};

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );
    return $self->render_json( {}, 'status' => HTTP_NOT_FOUND ) if not defined $activity;

    my $comment
          = $activity->save_comment(  { 'creator' => { 'object_id' => $user_id }, 'body' => $body } );

    return $self->render_json( {
            'comment_id'    => $comment->get_comment_id,
            'creation_time' => $comment->get_creation_time,
    } );

} ## end sub post_handler_user_activity_comment

sub post_handler_user_activity_recommendation {
    my $self = shift;

    my $rid         = $self->param('rid') || $self->req->json->{'rid'};
    my $user_id     = $self->param('user_id');
    my $activity_id = $self->param('activity_id');
    my $body        = $self->req->json->{'body'};

    return $self->render_json( {}, 'status' => HTTP_FORBIDDEN ) if not( $rid ~~ [ $user_id, 'internal' ] );

    my $environment = ActivityStream::Environment->new( controller => $self );

    my $activity = $environment->get_activity_factory->activity_instance_from_db( { 'activity_id' => $activity_id } );
    return $self->render_json( {}, 'status' => HTTP_NOT_FOUND ) if not defined $activity;

    my $new_activity = $activity->save_recommendation(
        { 'creator' => { 'object_id' => $user_id }, 'body' => $body } );

    if ( defined $new_activity ) {
        return $self->render_json( {
                'activity_id'   => $new_activity->get_activity_id,
                'creation_time' => $new_activity->get_creation_time,
        } );
    } else {
        return $self->render_json( {} );
    }
} ## end sub post_handler_user_activity_recommendation

1;
