package MiniApp::API::Thing::File;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Thing';

Readonly my %FIELDS => (
    'filename'                 => [ 'is' => 'rw', 'isa' => 'Str' ],
    'original_filepath'        => [ 'is' => 'rw', 'isa' => 'Str' ],
    'thumbernail_filepaths'    => [ 'is' => 'rw', 'isa' => 'ArrayRef[Str]' ],
    'intermedium_pdf_filepath' => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
    'size'                     => [ 'is' => 'rw', 'isa' => 'Int' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:ma_file$/} ) );
while ( my ( $field, $description ) = each(%FIELDS) ) {
    has $field => @$description;
}

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

sub is_commentable   { return 1 }
sub is_likeable      { return 1 }
sub is_recommendable { return 1 }

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

1;
