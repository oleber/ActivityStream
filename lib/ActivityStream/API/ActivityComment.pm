package ActivityStream::API::ActivityComment;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;

use ActivityStream::Util;

has 'comment_id' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'default' => sub {ActivityStream::Util::generate_id},
);

has 'user_id' => (
    'is'  => 'rw',
    'isa' => subtype( 'Str' => where {/^person:\w+$/} ),
);

has 'body' => (
    'is'  => 'rw',
    'isa' => 'Str',
);

has 'creation_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub { time() },
);

no Moose::Util::TypeConstraints;

sub to_struct {
    my ($self) = @_;
    return {
        'comment_id'    => $self->get_comment_id,
        'user_id'       => $self->get_user_id,
        'body'          => $self->get_body,
        'creation_time' => $self->get_creation_time,
    };
}

sub to_db_struct            { return shift->to_struct }
sub to_rest_response_struct { return shift->to_struct }

__PACKAGE__->meta->make_immutable;
no Moose;

1;
