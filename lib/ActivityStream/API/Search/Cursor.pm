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

sub _old_status_for {
    my ( $self, @consumer_docs ) = @_;

    my %status;
    foreach my $consumer_doc (@consumer_docs) {
        foreach my $consumer_source_doc ( values( %{ $consumer_doc->{'sources'} } ) ) {
            $status{ $consumer_source_doc->{'status'} } = 1;
        }
        @status{ map { $_->{'status'} } values( %{ $consumer_doc->{'sources'} } ) } = ();
    }

    return keys %status;
}

sub _next_interval {
    my ($self) = @_;

    my @days;
    foreach ( 1 .. $self->get_interval_size ) {
        push( @days, ActivityStream::Util::get_day_of( $self->get_next_time ) + 0 );
        $self->set_next_time( $self->get_next_time - $SECONDS_IN_A_DAY );
    }
    $self->set_interval_size( 2 * $self->get_interval_size );

    return @days;
}

sub _extract_activities {
    my ( $self, %consumer_doc_for ) = @_;

    my %activities;
    foreach my $consumer_doc ( values %consumer_doc_for ) {
        foreach my $consumer_source_doc ( values %{ $consumer_doc->{'sources'} } ) {
            %activities = ( %activities, %{ $consumer_source_doc->{'activity'} } );
        }
    }

    return sort { $activities{$b} <=> $activities{$a} } keys %activities;
}

sub load_next_days_activity_ids {
    my ($self) = @_;

    my $collection_consumer = $self->get_environment->get_collection_factory->collection_consumer;
    my $collection_source   = $self->get_environment->get_collection_factory->collection_source;

    my @days = $self->_next_interval;

    my @consumer_docs = $collection_consumer->find_consumers( {
            'consumer_id' => $self->get_filter->get_user,
            'day'         => { '$in' => \@days },
        } )->all;

    my %consumer_doc_for = map { $_->{'day'} => $_ } @consumer_docs;

    my $source_cursor = $collection_source->find_sources( {
            'source_id' => { '$in'  => $self->get_filter->get_see_sources },
            'day'       => { '$in'  => \@days },
            'status'    => { '$nin' => [ $self->_old_status_for(@consumer_docs) ] },
    } );

    while ( my $source_doc = $source_cursor->next ) {    # Just new or changed sources

        my %updates;
        while ( my ( $activity_id, $creation_time ) = each %{ $source_doc->{'activity'} } ) {
            my $day = ActivityStream::Util::get_day_of($creation_time);

            # prepare consumer updates
            my $update_data = ( $updates{$day}{ sprintf( 'sources.%s', $source_doc->{'source_id'} ) } //= {} );
            $update_data->{'status'} = $source_doc->{'status'};
            $update_data->{'activity'}{$activity_id} = $creation_time;

            # update consumer objects
            my $consumer_source_doc = ( $consumer_doc_for{$day}->{'sources'}{ $source_doc->{'source_id'} } //= {} );
            $consumer_source_doc->{'status'} = $source_doc->{'status'};
            $consumer_source_doc->{'activity'}{$activity_id} = $creation_time;
        }

        # update DB asynchronously
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

    $self->set_next_activity_ids( [ $self->_extract_activities(%consumer_doc_for) ] );    # sout by time

    return;
} ## end sub load_next_days_activity_ids

__PACKAGE__->meta->make_immutable;
no Moose;

1;
