package ActivityStream::API::Object;
use Moose;
use MooseX::FollowPBP;

has 'object_id' => (
    is       => 'rw',
    isa      => 'Str',
    required => 1,
);

sub to_struct {
    my ($self) = @_;
    return { 'object_id' => $self->get_object_id };
}

sub to_db_struct {
    my ($self) = @_;
    return $self->to_struct;
}

sub to_rest_response_struct {
    my ($self) = @_;
    return $self->to_struct;
}

sub from_struct {
    my ($pkg, $data) = @_;
    return $pkg->new($data);
}

sub from_db_struct {
    my ($pkg, $data) = @_;
    return $pkg->from_struct($data);
}

sub from_rest_request_struct {
    my ($pkg, $data) = @_;
    return $pkg->from_struct($data);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
