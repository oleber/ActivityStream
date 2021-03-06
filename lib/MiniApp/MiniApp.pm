package MiniApp::MiniApp;
use strict;
use warnings;

# This method will run once at server start
sub startup {
    my ( undef, $application ) = @_;

    my $environment = ActivityStream::Environment->new;

    # Routes
    my $r = $application->routes;

    #
    #   /web/miniapp/startpage

    $r->get('/')->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'get_handler' );

    $r->get('/web/miniapp/startpage')->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'get_handler' );

    $r->get('/web/miniapp/startpage/activitystream')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'get_handler_activitystream' );

    $r->post('/web/miniapp/startpage/share_status')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_share_status' );

    $r->post('/web/miniapp/startpage/share_link')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_share_link' );

    $r->post('/web/miniapp/startpage/share_file')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_share_file' );

    $r->post('/web/miniapp/startpage/:activity_id/delete')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_delete_activity' );

    $r->post('/web/miniapp/startpage/:activity_id/liker')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_liker_activity' );

    $r->post('/web/miniapp/startpage/:activity_id/comment')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_comment_activity' );

    $r->post('/web/miniapp/startpage/:activity_id/recommend')
          ->to( 'namespace' => 'MiniApp::WEB::StartPage', 'action' => 'post_handler_recommend_activity' );

    #
    # /web/miniapp/default

    $r->get('/web/miniapp/default/user_chooser')
          ->to( 'namespace' => 'MiniApp::WEB::Default', 'action' => 'get_handler_user_chooser' );

    $r->post('/web/miniapp/default/user_choosed')
          ->to( 'namespace' => 'MiniApp::WEB::Default', 'action' => 'post_handler_user_choosed' );

    #
    #   /web/miniapp/person/profile

    $r->get('/web/miniapp/person/profile/:person_id')
          ->to( 'namespace' => 'MiniApp::WEB::PersonProfile', 'action' => 'get_handler' );

    #
    #   /web/miniapp/activitystream/share_file
    $r->get('/web/miniapp/activitystream/share_file/show_uploaded_file/:file_id')
          ->to( 'namespace' => 'MiniApp::WEB::ActivityStream::ShareFile::Controller', 'action' => 'get_handler_show_uploaded_file' );

    return;
} ## end sub startup

1;
