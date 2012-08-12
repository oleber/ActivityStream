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

has 'see_source_id_suffixs' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[Str]',
    'lazy'    => 1,
    'default' => sub {
        my @see_source_id_suffixs;
        foreach my $see_source_id ( @{ shift->get_see_source_ids } ) {
            push(
                @see_source_id_suffixs,
                sprintf( '%s:%s',
                    MIME::Base64::encode_base64url( pack( 'V', ActivityStream::Util::calc_hash($see_source_id) ) ),
                    $see_source_id, ),
            );
        }
        return \@see_source_id_suffixs;
    },
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
