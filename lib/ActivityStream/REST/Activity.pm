package ActivityStream::REST::Activity;
use Mojo::Base 'ActivityStream::BaseController';

use Data::Dumper;
use Readonly;

use ActivityStream::API::Activity::Friendship;
use ActivityStream::Data::CollectionFactory;
use ActivityStream::Environment;

Readonly my $SECONDS_IN_A_DAY => 60 * 60 * 24;

sub get_day_of {
    my ($time) = @_;
    return int( $time / $SECONDS_IN_A_DAY );
}

sub post_handler_activity {
    my $self = shift;

    my $environment         = ActivityStream::Environment->new;
    my $collection_source   = $environment->get_collection_factory->collection_source;
    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $activity = ActivityStream::API::Activity::Friendship->from_rest_request_struct( $self->tx->req->json );
    $collection_activity->insert_activity( $activity->to_db_struct );

    foreach my $source ( $activity->get_sources ) {
        $collection_source->upsert_source(
            { 'source_id' => $source, 'day' => get_day_of( time() ) },
            { '$set' => { 'activity.' . $activity->get_activity_id => time } },
        );
    }

    $self->render_json( {
            'activity_id'   => $activity->get_activity_id,
            'creation_time' => $activity->get_creation_time,
        },
    );

    return;
} ## end sub post_handler_activity

sub get_handler_activity {
    my $self = shift;

    my $activity_id = $self->param('activity_id');
    my $rid         = $self->param('rid');

    my $environment         = ActivityStream::Environment->new;
    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $db_activity = $collection_activity->find_one_activity( { 'activity_id' => $activity_id } );

    if ( defined $db_activity ) {
        my $activity = ActivityStream::API::Activity::Friendship->from_db_struct($db_activity);

        $activity->prepare_load( $environment, { 'rid' => $rid } );
        $environment->get_async_user_agent->load_all;

        my $data = $activity->to_rest_response_struct;

        return $self->render_json( $activity->to_rest_response_struct );
    } else {
        return $self->render_json( {}, status => 404 );
    }
} ## end sub get_handler_activity

1;