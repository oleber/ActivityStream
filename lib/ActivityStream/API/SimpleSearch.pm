package ActivityStream::API::SimpleSearch;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);

use ActivityStream::API::SimpleSearch::Cursor;
use ActivityStream::API::SimpleSearch::Filter;

sub search {
    my ( $pkg, $environment, $filter ) = @_;

    if ( not blessed $filter ) {
        $filter = ActivityStream::API::SimpleSearch::Filter->new($filter);
    }

    return ActivityStream::API::SimpleSearch::Cursor->new( { 'environment' => $environment, 'filter' => $filter } );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
