package MiniApp::WEB::StartPage;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Cwd 'abs_path';
use Data::Dumper;
use File::Basename 'dirname';
use File::Spec;
use List::Util qw(min first);
use List::MoreUtils qw(any);
use Readonly;

Readonly my $CONFIG_FILEPATH =>
      File::Spec->join( File::Spec->splitdir( dirname(__FILE__) ), ('..') x 3, 'myapp_config.json' );
Readonly my $ABS_CONFIG_FILEPATH => abs_path($CONFIG_FILEPATH);
confess "File $CONFIG_FILEPATH not found" if not -f $CONFIG_FILEPATH;

$ENV{'ACTIVITY_STREAM_CONFIG_PATH'} //= $ABS_CONFIG_FILEPATH;

use ActivityStream::Environment;

sub get_handler {
    my ($c) = @_;

    my $rid = $c->session('rid');

    return $c->render('myapp/start_page');
}

sub get_handler_activitystream {
    my ($c) = @_;

    my $rid = $c->session('rid');

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new('/rest/activitystream/activity/user/$rid/activitystream');
    $url->query->param( 'rid' => $rid );
    $url->query->param( 'see_source_id' => [ %{ $environment->get_config->{'users'} } ] );

    $async_user_agent->add_get_web_request(
        $url,
        sub {
            my ($tx) = @_;

            # TODO: deal with error

            my $activity_factory = $environment->get_activity_factory;
            my @activities = map { $activity_factory->instance_from_rest_request_struct($_) }
                  @{ $tx->res->json->{'activities'} };

            $c->stash( 'environment' => $environment );
            $c->stash( 'activities'  => \@activities );
        },
    );

    $async_user_agent->load_all( sub { $c->render('myapp/start_page/activitystream') } );

    return;
} ## end sub get_handler_activitystream

sub post_handler_delete_activity {
    my ($c) = @_;

    my $rid = $c->session('rid');
    confess "rid not defined" if not defined $rid;

    my $activity_id = $c->param('activity_id');
    confess "activity_id not defined" if not defined $activity_id;

    my $environment = ActivityStream::Environment->new( controller => $c );

    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new( '/rest/activitystream/activity/' . $activity_id );
    $url->query->param( rid => $rid );

    $async_user_agent->add_delete_web_request( $url, sub { } );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    return;
} ## end sub post_handler_delete_activity

sub post_handler_share_status {
    my ($c) = @_;

    my $rid = $c->session('rid');

    confess "rid not defined" if not defined $rid;

    my $text = $c->param('text');

    my $environment = ActivityStream::Environment->new( controller => $c );

    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new('/rest/activitystream/activity');
    $url->query->param( rid => $rid );

    $async_user_agent->add_post_web_request(
        $url,
        Mojo::JSON->new->encode( {
                'actor'  => { 'object_id' => $rid },
                'verb'   => 'share',
                'object' => {
                    'object_id' => "ma_status:" . ActivityStream::Util::generate_id(),
                    'message'   => $text
                },
            },
        ),
        sub { },
    );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    return;
} ## end sub post_handler_share_status

sub post_handler_share_link {
    my ($c) = @_;

    return $c->redirect_to('/web/miniapp/startpage');
}

1;
