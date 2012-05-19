package ActivityStream::API::Search::Cursor;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

Readonly my $SECONDS_IN_A_DAY  => 24 * 60 * 60;
Readonly my $SECONDS_IN_A_YEAR => 365 * 24 * 60 * 60;

use ActivityStream::Data::Collection::Source;
use ActivityStream::API::Activity;
use ActivityStream::API::ActivityFactory;
use ActivityStream::Environment;

has 'environment' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::Environment',
    'required' => 1,
);

has 'filter' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Search::Filter',
    'required' => 1,
);

has 'next_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub {time},
);

has 'next_activity_ids' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'default' => sub { [] },
);

has 'interval_size' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => 2,
);

sub next_activity {
    my ($self) = @_;

    while ( $self->get_next_time > time - $SECONDS_IN_A_YEAR ) {

        # load already searched activites
        while ( @{ $self->get_next_activity_ids } ) {
            my $activity_id = shift @{ $self->get_next_activity_ids };
            my $activity    = ActivityStream::API::ActivityFactory->instance_from_db( $self->get_environment,
                { 'activity_id' => $activity_id } );
            return $activity if defined $activity;
        }

        # nead to search furder
        $self->load_next_days_activity_ids;
    }

    return;
}

sub load_next_days_activity_ids {
    my ($self) = @_;

    my $collection_consumer = $self->get_environment->get_collection_factory->collection_consumer;
    my $collection_source   = $self->get_environment->get_collection_factory->collection_source;

    my @days;
    foreach ( 1 .. $self->get_interval_size ) {
        push( @days, ActivityStream::Util::get_day_of( $self->get_next_time ) + 0 );
        $self->set_next_time( $self->get_next_time - $SECONDS_IN_A_DAY );
    }
    $self->set_interval_size( 2 * $self->get_interval_size );

    my $consumer_cursor = $collection_consumer->find_consumers( {
            'consumer_id' => $self->get_filter->get_user,
            'day'         => { '$in' => \@days },
    } );
    my @consumer_docs = $consumer_cursor->all;
    my %status;

    my %consumer_doc_for;
    foreach my $consumer_doc (@consumer_docs) {
        @status{ map { $_->{'status'} } values( %{ $consumer_doc->{'sources'} } ) } = ();
        $consumer_doc_for{ $consumer_doc->{'day'} } = $consumer_doc;
    }

    my $source_cursor = $collection_source->find_sources( {
            'source_id' => { '$in'  => $self->get_filter->get_see_sources },
            'day'       => { '$in'  => \@days },
            'status'    => { '$nin' => [ keys %status ] },
    } );

    while ( my $source_doc = $source_cursor->next ) {
        # prepare consumer updates
        my %updates;
        while ( my ( $activity_id, $creation_time ) = each %{ $source_doc->{'activity'} } ) {
            my $day = ActivityStream::Util::get_day_of($creation_time);
 
            my $update_data = ( $updates{$day}{ sprintf( 'sources.%s', $source_doc->{'source_id'} ) } //= {} );
            my $consumer_data = ( $consumer_doc_for{$day}->{'sources'}{ $source_doc->{'source_id'} } //= {} );

            $update_data->{'status'} = $consumer_data->{'status'} = $source_doc->{'status'};
            $update_data->{'activity'}{$activity_id} = $consumer_data->{'activity'}{$activity_id} = $creation_time;
        }

        $self->get_environment->get_async_user_agent->add(
            undef,
            sub {
                while ( my ( $day, $data ) = each %updates ) {
                    $collection_consumer->upsert_consumer(
                        { 'day'  => $day, 'consumer_id' => $self->get_filter->get_user },
                        { '$set' => $data },
                    );
                }
            },
        );
    } ## end while ( my $source_doc = ...)

    my %activities;
    foreach my $consumer_doc ( values %consumer_doc_for ) {
        foreach my $source_doc ( values %{$consumer_doc->{'sources'}} ) {
            %activities = ( %activities, %{ $source_doc->{'activity'} } );
        }
    }

    $self->set_next_activity_ids( [ sort { $activities{$b} <=> $activities{$a} } keys %activities ] );    # sout by time

    return;
} ## end sub load_next_days_activity_ids

__PACKAGE__->meta->make_immutable;
no Moose;

1;
