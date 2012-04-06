package ActivityStream;
use Mojo::Base 'Mojolicious';

# This method will run once at server start
sub startup {
    my $self = shift;

    # Documentation browser under "/perldoc"
    $self->plugin('PODRenderer');

    # Routes
    my $r = $self->routes;

    # Normal route to controller
    $r->route('/welcome')->to('example#welcome');
    $r->post("/rest/activitystream")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'post_handler_activity' );
    $r->get("/rest/activitystream/activity/:activity_id")
          ->to( namespace => 'ActivityStream::REST::Activity', action => 'get_handler_activity' );

}

1;
