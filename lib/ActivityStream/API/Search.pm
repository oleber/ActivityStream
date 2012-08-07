package ActivityStream::API::Search;
use Moose;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);

use ActivityStream::API::Search::Cursor;
use ActivityStream::API::Search::Filter;

sub search {
    my ( $pkg, $environment, $filter ) = @_;

    if ( not blessed $filter ) {
        $filter = ActivityStream::API::Search::Filter->new($filter);
    }

    return ActivityStream::API::Search::Cursor->new( { 'environment' => $environment, 'filter' => $filter } );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
