package MiniApp::API::Object::Link;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Object';

Readonly my %FIELDS => (
    'url'           => [ 'is' => 'rw', 'isa' => 'Str', 'required' => 1 ],
    'image'         => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
    'title'         => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
    'description'   => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
    'site_name'     => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:ma_link$/} ) );
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
    foreach my $field ( keys %FIELDS ) {
        my $getter = "get_$field";
        $data->{$field} = $self->$getter();
    }

    return $data;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
