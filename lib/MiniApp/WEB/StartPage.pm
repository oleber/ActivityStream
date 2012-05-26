package MiniApp::WEB::StartPage;
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
      File::Spec->join( File::Spec->splitdir( dirname(__FILE__) ), '..', '..', 'myapp_config.json' );
Readonly my $ABS_CONFIG_FILEPATH => abs_path($CONFIG_FILEPATH);
confess "File $CONFIG_FILEPATH not found" if not -f $CONFIG_FILEPATH;

$ENV{'ACTIVITY_STREAM_CONFIG_PATH'} //= $ABS_CONFIG_FILEPATH;

sub get_handler {
    my $self = shift;

    my $rid = $self->param('rid');

    return $self->render( 'myapp/start_page' );
} ## end sub post_handler_activity

sub post_handler_share_status {
    my ( $c ) = @_;

    return $c->redirect_to('/web/startpage');
}

sub post_handler_share_link{
    my ( $c ) = @_;

    return $c->redirect_to('/web/startpage');
}

1;
