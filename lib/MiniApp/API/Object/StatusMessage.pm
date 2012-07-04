package MiniApp::API::Object::StatusMessage;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Object';

Readonly my %FIELDS => (
    'message'  => [ 'is' => 'rw', 'isa' => 'Str' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:ma_status$/} ) );
while ( my ( $field, $description ) = each(%FIELDS) ) {
    has $field => @$description;
}

no Moose::Util::TypeConstraints;

sub to_rest_response_struct {
    my ($self) = @_;

    my $data = $self->SUPER::to_rest_response_struct;
    foreach my $field ( keys %FIELDS ) {
        my $getter = "get_$field";
        $data->{$field} = $self->$getter();
    }

    return $data;
}

sub to_db_struct {
    my ($self) = @_;

    my $data = $self->SUPER::to_db_struct;
    $data->{'message'} = $self->get_message;

    return $data;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
