package ActivityStream::API::Search::Cursor;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;
use Tie::IxHash;
use Try::Tiny;

use ActivityStream::Data::Collection::Source;
use ActivityStream::API::Activity;
use ActivityStream::API::ActivityFactory;
use ActivityStream::API::Search::Filter;
use ActivityStream::Environment;

has 'environment' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::Environment',
    'required' => 1,
);

has 'collection_activity' => (
    'is'      => 'rw',
    'isa'     => 'ActivityStream::Data::Collection::Activity',
    'lazy'    => 1,
    'default' => sub { return shift->get_environment->get_collection_factory->collection_activity },
);

has 'filter' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Search::Filter',
    'required' => 1,
);

has 'now_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'lazy'    => 1,
    'default' => sub {time},
);

has 'start_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'lazy'    => 1,
    'default' => sub {time},
);

has 'intervals' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'lazy'    => 1,
    'default' => sub {
        my ($self) = @_;
        my $time_now = $self->get_now_time;
        my @intervals;

        my $index = 0;

        $time_now = int( $time_now / ( 60 * 60 ) );
        push( @intervals, $index + 10 * $time_now );
        $time_now--;

        while ( @intervals < 20 ) {
            if ( ( $index < 9 ) && ( $time_now % 2 == 1 ) ) {
                $time_now = ( $time_now - 1 ) / 2;
                $index++;
            }

            push( @intervals, $index + 10 * $time_now );
            $time_now--;
        }

        return \@intervals;
    },
);

has 'next_activity_ids' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'default' => sub { [] },
);

sub BUILD {
    my ($self) = @_;

    $self->get_collection_activity->get_collection->ensure_index( Tie::IxHash->new( 'timebox' => 1 ), { safe => 1 } );
    $self->get_collection_activity->get_collection->ensure_index( Tie::IxHash->new( 'activity_id' => 1 ) );

    return;
}

sub next_activity {
    my ($self) = @_;

    if ( @{ $self->get_next_activity_ids } ) {
        my $activity_id = shift @{ $self->get_next_activity_ids };
        my $activity;

        if ( defined $activity_id ) {
            try {
                $activity = $self->get_environment->get_activity_factory->activity_instance_from_db(
                    { 'activity_id' => $activity_id } );
            }
            catch {
                warn "Failing loading $activity_id: $_";
                $activity = $self->next_activity;
            };
        }

        return $activity if defined $activity;
    }

    if ( @{ $self->get_intervals } ) {
        my $interval = shift @{ $self->get_intervals };

        my $found_activities_cursor = $self->get_collection_activity->find_activities(
            { timebox => { '$in' => [ map { "$interval:$_" } @{ $self->get_filter->get_see_source_ids } ], } } );

        my @objects = $found_activities_cursor->all;
        @objects = sort { $b->{'creation_time'} <=> $a->{'creation_time'} } @objects;
        $self->set_next_activity_ids( [ map { $_->{'activity_id'} } @objects ] );

        return $self->next_activity;
    } else {
        return;
    }
} ## end sub next_activity

__PACKAGE__->meta->make_immutable;
no Moose;

1;
