package ActivityStream;
use strict;
use warnings;
use Mojo::Base 'Mojolicious';

use HTTP::Status qw(:constants);
use Try::Tiny;

use ActivityStream::REST::Constants;

our $VERSION = 0.0;

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    $self->hook(
        around_dispatch => sub {
            my ( $next, $c ) = @_;
            try {
                $next->();
            }
            catch {
                my $exception = $_;

                if ( $exception->isa('ActivityStream::X::ActivityNotFound') ) {
                    return $c->render_json(
                        { 'error' => $ActivityStream::REST::Constants::ERROR_MESSAGE_ACTIVITY_NOT_FOUND },
                        'status' => HTTP_NOT_FOUND );
                }

                warn "EXCEPTION: $_";
                die $_;
            },;
        },
    );

    # Routes
    my $r = $self->routes;

    # Normal route to controller
    $r->post('/rest/activitystream/activity')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'post_handler_activity' );

    $r->delete('/rest/activitystream/activity/:activity_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'delete_handler_activity' );

    $r->get('/rest/activitystream/activity/:activity_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'get_handler_activity' );

    $r->get('/rest/activitystream/activity/user/:user_id/activitystream')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'get_handler_user_activitystream' );

    $r->post('/rest/activitystream/user/:user_id/like/activity/:activity_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'post_handler_user_activity_like' );

    $r->delete('/rest/activitystream/activity/:activity_id/like/:like_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'delete_handler_activity_like' );

    $r->post('/rest/activitystream/user/:user_id/comment/activity/:activity_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'post_handler_user_activity_comment' );

    $r->get('/')
        ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'get_handler' );

    $r->get('/web/startpage')
        ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'get_handler' );

    $r->post('/web/startpage/share_status')
        ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_share_status' );

    $r->post('/web/startpage/share_link')
        ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_share_link' );

    return;
} ## end sub startup

1;
