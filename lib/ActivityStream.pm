package ActivityStream;
use strict;
use warnings;
use Mojo::Base 'Mojolicious';

use Carp;
use Data::Dumper;
use Digest::MD5 qw(md5_hex);
use HTTP::Status qw(:constants);
use Try::Tiny;

use ActivityStream::Environment;
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

    $self->app->helper( 'md5_hex' => sub { my (undef, $string) = @_; md5_hex($string) } );

    my $environment = ActivityStream::Environment->new;

    if ( defined $environment->get_config->{'packages'} ) {
        foreach my $package ( values %{ $environment->get_config->{'packages'} } ) {
            eval "use $package;";
            confess($@) if $@;
        }
    }

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

    $r->post('/rest/activitystream/user/:user_id/recommend/activity/:activity_id')
          ->to( 'namespace' => 'ActivityStream::REST::Activity', 'action' => 'post_handler_user_activity_recommendation' );


    my $mojolicious_startup = $environment->get_config->{'packages'}->{'mojolicious_startup'};
    if ( defined $mojolicious_startup ) {
        $mojolicious_startup->startup($self);
    }

    return;
} ## end sub startup

1;
