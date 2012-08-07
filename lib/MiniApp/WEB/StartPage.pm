package MiniApp::WEB::StartPage;
use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

use Carp;
use Cwd 'abs_path';
use Data::Dumper;
use File::Basename 'dirname';
use File::Path qw(make_path);
use File::Spec;
use HTTP::Status qw( :constants );
use Mojo::JSON;
use Mojo::URL;
use Readonly;
use Try::Tiny;

use MiniApp::Utils::FileToPNG;

Readonly my $CONFIG_FILEPATH =>
      File::Spec->join( File::Spec->splitdir( dirname(__FILE__) ), ('..') x 3, 'myapp_config.json' );
Readonly my $ABS_CONFIG_FILEPATH => abs_path($CONFIG_FILEPATH);
confess "File $CONFIG_FILEPATH not found" if not -f $CONFIG_FILEPATH;

$ENV{'ACTIVITY_STREAM_CONFIG_PATH'} //= $ABS_CONFIG_FILEPATH;

use ActivityStream::Environment;

sub get_handler {
    my ($c) = @_;

    my $rid = $c->session('rid');
    my $environment = ActivityStream::Environment->new( controller => $c );

    return $c->render( 'myapp/start_page', environment => $environment );
}

sub get_handler_activitystream {
    my ($c) = @_;

    my $rid = $c->session('rid');

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new('/rest/activitystream/activity/user/$rid/activitystream');
    $url->query->param( 'rid'           => $rid );
    $url->query->param( 'see_source_id' => [ %{ $environment->get_config->{'users'} } ] );

    $async_user_agent->add_get_web_request(
        $url,
        sub {
            my ($tx) = @_;

            # TODO: deal with error

            my $activity_factory = $environment->get_activity_factory;
            my @activities = map { $activity_factory->activity_instance_from_rest_response_struct($_) }
                  @{ $tx->res->json->{'activities'} };

            warn( Dumper( [ map { $_->to_db_struct } @activities ] ) );

            $c->stash( 'environment' => $environment );
            $c->stash( 'activities'  => \@activities );
        },
    );

    $async_user_agent->load_all( sub { $c->render( 'myapp/start_page/activitystream', environment => $environment ) } );

    $c->render_later;
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

    $c->render_later;

    return;
} ## end sub post_handler_delete_activity

sub post_handler_recommend_activity {
    my ($c) = @_;

    my $rid = $c->session('rid');
    confess "rid not defined" if not defined $rid;

    my $activity_id = $c->param('activity_id');
    confess "activity_id not defined" if not defined $activity_id;

    my $body = $c->param('body') // 'TODO';
    confess "body not defined" if not defined $body;
    confess "body length = 0"  if 0 == length $body;

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new( sprintf( "/rest/activitystream/user/%s/recommend/activity/%s", $rid, $activity_id ) );
    $url->query->param( rid => $rid );

    my $json = Mojo::JSON->new;

    $async_user_agent->add_post_web_request( $url, $json->encode( { 'body' => $body } ), sub { } );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    $c->render_later;

    return;
} ## end sub post_handler_recommend_activity

sub post_handler_comment_activity {
    my ($c) = @_;

    my $rid = $c->session('rid');
    confess "rid not defined" if not defined $rid;

    my $activity_id = $c->param('activity_id');
    confess "activity_id not defined" if not defined $activity_id;

    my $body = $c->param('body');
    confess "body not defined" if not defined $body;
    confess "body length = 0"  if 0 == length $body;

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new( sprintf( "/rest/activitystream/user/%s/comment/activity/%s", $rid, $activity_id ) );
    $url->query->param( rid => $rid );

    my $json = Mojo::JSON->new;

    $async_user_agent->add_post_web_request( $url, $json->encode( { 'rid' => $rid, 'body' => $body } ), sub { } );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    $c->render_later;

    return;
} ## end sub post_handler_comment_activity

sub post_handler_liker_activity {
    my ($c) = @_;

    my $rid = $c->session('rid');
    confess "rid not defined" if not defined $rid;

    my $activity_id = $c->param('activity_id');
    confess "activity_id not defined" if not defined $activity_id;

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $url = Mojo::URL->new( sprintf( "/rest/activitystream/user/%s/like/activity/%s", $rid, $activity_id ) );
    $url->query->param( rid => $rid );

    my $json = Mojo::JSON->new;

    $async_user_agent->add_post_web_request( $url, $json->encode( { 'rid' => $rid } ), sub { } );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    $c->render_later;

    return;
} ## end sub post_handler_liker_activity

sub post_handler_share_status {
    my ($c) = @_;

    my $rid = $c->session('rid');

    confess "rid not defined" if not defined $rid;

    my $text = $c->param('text');

    my $environment = ActivityStream::Environment->new( controller => $c );
    my $async_user_agent = $environment->get_async_user_agent;

    my $post_url = Mojo::URL->new('/rest/activitystream/activity');
    $post_url->query->param( rid => $rid );

    $async_user_agent->add_post_web_request(
        $post_url,
        Mojo::JSON->new->encode( {
                'actor'  => { 'object_id' => $rid },
                'verb'   => 'share',
                'object' => {
                    'object_id' => ActivityStream::Util::generate_id() . ':ma_status',
                    'message'   => $text
                },
            },
        ),
        sub { },
    );

    $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

    $c->render_later;

    return;
} ## end sub post_handler_share_status

Readonly my @HTML_FIELD_MAPS => (
    [ 'head meta[property="og:image"]'       => 'image',       sub { shift->attrs('content') } ],
    [ 'head meta[property="og:title"]'       => 'title',       sub { shift->attrs('content') } ],
    [ 'head title'                           => 'title',       sub { shift->all_text(0) } ],
    [ 'head meta[name="description"]'        => 'description', sub { shift->attrs('content') } ],
    [ 'head meta[property="og:description"]' => 'description', sub { shift->attrs('content') } ],
    [ 'head meta[property="og:site_name"]'   => 'site_name',   sub { shift->attrs('content') } ],

);

sub post_handler_share_link {
    my ($c) = @_;

    my $rid = $c->session('rid');
    my $environment = ActivityStream::Environment->new( controller => $c );

    my $url = $c->param('link');

    if ( not defined $url ) {
        $c->flash( 'ERROR' => { 'UNDEFINED' => 'url' } );
        $c->redirect_to( '/web/miniapp/startpage', 'status' => 400 );
    }

    my $tx = Mojo::UserAgent->new->max_redirects(5)->get($url);

    if ( $tx->success ) {
        my $dom = $tx->res->dom;
        my %link_data = ( 'url' => $url );

        foreach my $html_field_map (@HTML_FIELD_MAPS) {
            my ( $css3, $field, $cb ) = @{$html_field_map};

            next if defined( $link_data{$field} );

            my $value_elem = $dom->at($css3);
            next if not defined $value_elem;

            my $value = $cb->($value_elem);
            $link_data{$field} = $value if defined $value;
        }

        my $post_url = Mojo::URL->new('/rest/activitystream/activity');
        $post_url->query->param( rid => $rid );

        my $async_user_agent = $environment->get_async_user_agent;
        $async_user_agent->add_post_web_request(
            $post_url,
            Mojo::JSON->new->encode( {
                    'actor'  => { 'object_id' => $rid },
                    'verb'   => 'share',
                    'object' => {
                        'object_id' => ActivityStream::Util::generate_id() . ':ma_link',
                        %link_data
                    },
                },
            ),
            sub { },
        );

        $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

        $c->render_later;
    } else {
        $c->flash( 'ERROR' => { 'MESSAGE' => "Can't load URL: $url" } );
        $c->redirect_to( '/web/miniapp/startpage', 'status' => 500 );
    }

    return $c->render_later;
} ## end sub post_handler_share_link

sub post_handler_share_file {
    my ($c) = @_;

    my $rid = $c->session('rid');

    return $c->render( 'text' => 'File is too big.', status => HTTP_REQUEST_ENTITY_TOO_LARGE )
          if $c->req->is_limit_exceeded;

    my $upfile = $c->param('upfile');

    return $c->render( 'text' => 'File is too big.', status => HTTP_REQUEST_ENTITY_TOO_LARGE )
          if $upfile->size > 2**20;    # 2 Mb

    my $share_id = ActivityStream::Util::generate_id();
    my $environment = ActivityStream::Environment->new( controller => $c );

    my $storage_path = $environment->get_config->{'myapp'}{'stories'}{'share_file'}{'storage_path'};
    my $directory_path = File::Spec->join( $storage_path, ( $share_id =~ /(.)(.)(.)(.)(.)(.)(.)(.)(.)(.)(.*)/ ) );

    confess("Directory for the storage was already created: $directory_path") if -e $directory_path;
    make_path( $directory_path, { 'mode' => oct('0700') } );
    confess("Directory for the storage wasn't found: $directory_path") if not -d -r $directory_path;

    my $upfile_filename = $upfile->filename;
    $upfile_filename =~ s/[^\w.]/_/g;
    my $original_filepath = File::Spec->join( $directory_path, $upfile_filename );

    $upfile->move_to($original_filepath);

    my $file_to_png = try { MiniApp::Utils::FileToPNG->new( 'filepath' => $original_filepath ) } catch { warn $_ };
    if ( not defined $file_to_png ) {
        return $c->render( 'text' => 'Unrecognized media type.', status => HTTP_UNSUPPORTED_MEDIA_TYPE );
    }

    return try {
        $file_to_png->convert;

        my $converted_dirpath = File::Spec->join( $directory_path, 'converted' );
        make_path( $converted_dirpath, { 'mode' => oct('0700') } );
        confess("Directory for the converted wasn't found: $converted_dirpath") if not -d -r $converted_dirpath;

        my @thumbnail_filepaths;
        foreach my $converted_filepath ( @{ $file_to_png->get_converted_filepaths } ) {
            my ( undef, undef, $file ) = File::Spec->splitpath($converted_filepath);
            my $thumbnail_filepath = File::Spec->join( $converted_dirpath, $file );
            my $system_ret = system( 'convert', '-resize', '600x500', $converted_filepath, $thumbnail_filepath );
            if ( $system_ret != 0 or -f -r $thumbnail_filepath ) {
                confess("Thumbernail creation failed: $converted_dirpath") if not -f -r $thumbnail_filepath;
            }

            push( @thumbnail_filepaths, $thumbnail_filepath );
        }

        my $post_url = Mojo::URL->new('/rest/activitystream/activity');
        $post_url->query->param( rid => $rid );

        my $async_user_agent = $environment->get_async_user_agent;
        $async_user_agent->add_post_web_request(
            $post_url,
            Mojo::JSON->new->encode( {
                    'actor'  => { 'object_id' => $rid },
                    'verb'   => 'share',
                    'object' => {
                        'object_id'         => ActivityStream::Util::generate_id() . ':ma_file',
                        'filename'          => $upfile_filename,
                        'size'              => $upfile->size,
                        'original_filepath' => File::Spec->abs2rel( $original_filepath, $storage_path ),
                        'thumbernail_filepaths' =>
                              [ map { File::Spec->abs2rel( $_, $storage_path ) } @thumbnail_filepaths ],

                    },
                },
            ),
            sub {},
        );

        $async_user_agent->load_all( sub { $c->redirect_to('/web/miniapp/startpage') } );

        $c->render_later;

    } ## end try
    catch {
        warn $_;
        $c->render( 'text' => 'Fail file convertion.', 'status' => HTTP_INTERNAL_SERVER_ERROR );
    }
} ## end sub post_handler_share_file

1;
