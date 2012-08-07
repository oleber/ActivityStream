package ActivityStream::API::Search::Filter;

use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;

has 'consumer_id' => (
    'is'       => 'rw',
    'isa'      => 'Str',
    'required' => 1,
);

has 'see_source_ids' => (
    'is'       => 'rw',
    'isa'      => 'ArrayRef[Str]',
    'required' => 1,
);

has 'ignore_source_ids' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'default' => sub { [] },
);

has 'ignore_activities' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'default' => sub { [] },
);

has 'limit' => (
    'is'      => 'rw',
    'isa'     => subtype( 'Int' => where sub { $_ > 0 and $_ <= 25 } ),
    'default' => 1,
);

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

1;
