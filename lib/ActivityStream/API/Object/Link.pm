package ActivityStream::API::Object::Link;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;
use Readonly;

extends 'ActivityStream::API::Object';

Readonly my %FIELDS => (
    'title'       => [ 'is' => 'rw', 'isa' => 'Str' ],
    'description' => [ 'is' => 'rw', 'isa' => 'Str' ],
    'url'         => [ 'is' => 'rw', 'isa' => 'Str' ],
    'image_url'   => [ 'is' => 'rw', 'isa' => 'Str' ],
);

has '+object_id' => ( 'isa' => subtype( 'Str' => where {/^\w+:link$/} ) );
while ( my ( $field, $description ) = each(%FIELDS) ) {
    has $field => @$description;
}

no Moose::Util::TypeConstraints;

sub create_request {
    my ( $self, $data ) = @_;
    my $url = sprintf( '/test/link/%s/%s', $self->get_object_id, $data->{'rid'} );
    $url =~ s/:/__/g;
    return $url;
}

sub create_test_response {
    my ( undef, $data ) = @_;

    return sub {
        shift->render_json( {
                'title'       => $data->{'title'}       // 'Link Title',
                'description' => $data->{'description'} // 'Link Description',
                'url'         => $data->{'url'}         // 'http://link/link_response',
                'image_url'   => $data->{'image_url'}   // 'http://link/link_response/large_image',
            },
        );
    };
}

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

    $self->SUPER::prepare_load( $args );

    $self->get_environment->get_async_user_agent->add_get_web_request(
        $self->create_request($args),
        sub {
            my ( $tx ) = @_;

            if ( $tx->res->is_status_class(200) ) {
                my $json = $tx->res->json;

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
