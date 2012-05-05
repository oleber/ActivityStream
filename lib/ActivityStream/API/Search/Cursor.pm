package ActivityStream::API::Search::Cursor;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

Readonly my $SECONDS_IN_A_DAY => 24 * 60 * 60;
Readonly my $SECONDS_IN_A_YEAR => 365*24 * 60 * 60;

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
        my $source_cursor = $self->get_environment->get_collection_factory->collection_source->find_source( {
                'source_id' => { '$in' => $self->get_filter->get_see_sources },
                'day' => ActivityStream::Util::get_day_of( $self->get_next_time )+0,
        } );

        my %activities;
        while ( my $source_doc = $source_cursor->next ) {
            %activities = ( %activities, %{ $source_doc->{'activity'} } );
        }

        $self->set_next_activity_ids( [ sort { $activities{$b} <=> $activities{$a} } keys %activities ] );

        $self->set_next_time( $self->get_next_time - $SECONDS_IN_A_DAY );
    } ## end while ( $self->get_next_time...)

    return;
} ## end sub next_activity

__PACKAGE__->meta->make_immutable;
no Moose;

1;
