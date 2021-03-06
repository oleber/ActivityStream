package MiniApp::API::Thing::Person;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Thing';

Readonly my %FIELDS => (
    'first_name'  => [ 'is' => 'rw', 'isa' => 'Str' ],
    'last_name'   => [ 'is' => 'rw', 'isa' => 'Str' ],
    'profile_url' => [
        'is'    => 'rw',
        'isa'   => 'Str',
        default => sub { my $self = shift; return "/web/miniapp/person/profile/" . $self->get_object_id }
    ],
    'large_image'  => [ 'is' => 'rw', 'isa' => 'Str' ],
    'medium_image' => [ 'is' => 'rw', 'isa' => 'Str' ],
    'small_image'  => [ 'is' => 'rw', 'isa' => 'Str' ],
    'company'      => [ 'is' => 'rw', 'isa' => 'Maybe[Str]' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:ma_person$/} ) );
while ( my ( $field, $description ) = each(%FIELDS) ) {
    has $field => @$description;
}

__PACKAGE__->meta->make_immutable;
no Moose::Util::TypeConstraints;
no Moose;

sub is_commentable   { return 1 }
sub is_likeable      { return 1 }
sub is_recommendable { return 1 }

sub to_rest_response_struct {
    my ($self) = @_;

    my $data = $self->SUPER::to_rest_response_struct;
    foreach my $field ( keys %FIELDS ) {
        my $getter = "get_$field";
        $data->{$field} = $self->$getter();
    }

    return $data;
}

sub prepare_load {
    my ( $self, $args ) = @_;

    $self->set_loaded_successfully(0);

    $self->SUPER::prepare_load($args);

    my $data = $self->get_environment->get_config->{'users'}->{ $self->get_object_id };

    warn "data not found with object_id = " . $self->get_object_id if not defined $data;

    foreach my $field ( keys %FIELDS ) {
        next if not exists $data->{$field};
        my $setter = "set_$field";
        $self->$setter( $data->{$field} );
    }

    $self->set_loaded_successfully(1);

    return;
} ## end sub prepare_load

sub get_full_name {
    my ($self) = @_;
    return join( ' ', $self->get_first_name, $self->get_last_name );
}

1;
