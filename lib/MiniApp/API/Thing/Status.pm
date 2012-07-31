package MiniApp::API::Thing::Status;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Thing';

Readonly my %FIELDS => ( 'message' => [ 'is' => 'rw', 'isa' => 'Str' ], );

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:ma_status$/} ) );
while ( my ( $field, $description ) = each(%FIELDS) ) {
    has $field => @$description;
}

no Moose::Util::TypeConstraints;

sub _to_helper {
    my ( $self, $data ) = @_;

    foreach my $field ( keys %FIELDS ) {
        my $getter = "get_$field";
        $data->{$field} = $self->$getter();
    }

    return $data;
}

sub to_simulate_rest_struct {
    my ($self) = @_;
    return $self->_to_helper( $self->SUPER::to_simulate_rest_struct );
}

sub to_db_struct {
    my ($self) = @_;
    return $self->_to_helper( $self->SUPER::to_db_struct );
}

sub to_rest_response_struct {
    my ($self) = @_;
    return $self->_to_helper( $self->SUPER::to_rest_response_struct );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
