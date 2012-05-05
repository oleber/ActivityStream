package ActivityStream;
use Mojo::Base 'Mojolicious';

use Try::Tiny;

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

                return $c->render_json( {}, status => 404 ) if $exception->isa('ActivityStream::X::ActivityNotFound');

                warn "EXCEPTION: $_";
                die $_;
            },;
        },
    );

    # Routes
    my $r = $self->routes;

    # Normal route to controller
    $r->route('/welcome')->to('example#welcome');

    $r->post("/rest/activitystream/activity")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'post_handler_activity' );

    $r->get("/rest/activitystream/activity/:activity_id")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'get_handler_activity' );

    $r->get("/rest/activitystream/activity/user/:user_id/activitystream")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'get_handler_user_activitystream' );

    $r->post("/rest/activitystream/user/:user_id/like/activity/:activity_id")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'post_handler_user_activity_like' );

    $r->post("/rest/activitystream/user/:user_id/comment/activity/:activity_id")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'post_handler_user_activity_comment' );
} ## end sub startup

1;
