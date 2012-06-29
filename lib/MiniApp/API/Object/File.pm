package MiniApp::API::Object::File;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Object';

Readonly my %FIELDS => (
    'filename'              => [ 'is' => 'rw', 'isa' => 'Str' ],
    'original_filepath'     => [ 'is' => 'rw', 'isa' => 'Str' ],
    'thumbernail_filepaths' => [ 'is' => 'rw', 'isa' => 'ArrayRef[Str]' ],
    'size'                  => [ 'is' => 'rw', 'isa' => 'Int' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^ma_file:\w+$/} ) );
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
