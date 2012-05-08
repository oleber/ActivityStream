package ActivityStream::API::Object::Person;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Data::Dumper;
use Carp;
use Readonly;

extends 'ActivityStream::API::Object';

Readonly my %FIELDS => (
    'first_name'  => [ 'is' => 'rw', 'isa' => 'Str' ],
    'last_name'   => [ 'is' => 'rw', 'isa' => 'Str' ],
    'profile_url' => [ 'is' => 'rw', 'isa' => 'Str' ],
    'large_image' => [ 'is' => 'rw', 'isa' => 'Str' ],
    'small_image' => [ 'is' => 'rw', 'isa' => 'Str' ],
    'company'     => [ 'is' => 'rw', 'isa' => 'Str' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^person:\w+$/} ) );
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

sub prepare_load {
    my ( $self, $environment, $args ) = @_;
    my $async_user_agent = $environment->get_async_user_agent;
    $async_user_agent->add(
        $async_user_agent->create_request_person( { 'object_id' => $self->get_object_id, %{$args} } ),
        sub {
            my ( undef, $response ) = @_;

            if ( $response->is_status_class(200) ) {
                my $json = $response->json;

                foreach my $field ( keys %FIELDS ) {
                    my $setter = "set_$field";
                    $self->$setter( $json->{$field} );
                }

                $self->set_loaded_successfully(1);
            } else {
                $self->set_loaded_successfully(0);
            }

            return $self->get_loaded_successfully;
        },
    );

    return;
} ## end sub prepare_load

__PACKAGE__->meta->make_immutable;
no Moose;

1;
