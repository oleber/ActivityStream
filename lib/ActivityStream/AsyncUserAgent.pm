package ActivityStream::AsyncUserAgent;
use Moose;
use MooseX::FollowPBP;

use Data::Dumper;
use HTTP::Request::Common;
use Mojo::JSON;
use Mojo::Message::Response;

use Moose;
use HTTP::Async;
use Storable qw(dclone);

has 'no_request_tasks' => (
    is      => 'rw',
    isa     => 'ArrayRef[CODE]',
    default => sub { [] },
);

has 'request_tasks' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[CODE]]',
    default => sub { {} },
);

my $cache = {};

has 'cache' => (
    is      => 'rw',
    isa     => 'HashRef[HTTP::Response]',
    default => sub { $cache // {} },
    traits  => ['Hash'],
    handles => {
        put_response_to => 'set',
        get_response_to => 'get',
    },
);

has '_async' => (
    is      => 'rw',
    isa     => 'HTTP::Async',
    default => sub { HTTP::Async->new },
);

sub _convert_response {
    my ( $self, $http_response ) = @_;
    my $mojo_message_reponse = Mojo::Message::Response->new;
    $mojo_message_reponse->code( $http_response->code );
    $mojo_message_reponse->body( $http_response->decoded_content );
    return $mojo_message_reponse;
}

sub add {
    my ( $self, $request, $cb ) = @_;

    if ( defined $request ) {
        my $request_as_str = $request->as_string;

        if ( defined( my $response = $self->get_response_to($request_as_str) ) ) {
            $self->add( undef, sub { $cb->( $self, $self->_convert_response($response) ) } );
        } else {
            if ( not exists $self->get_request_tasks->{$request_as_str} ) {
                $self->_get_async->add($request);
            }
            push( @{ $self->get_request_tasks->{$request_as_str} }, $cb );
        }
    } else {
        push( @{ $self->get_no_request_tasks }, $cb );
    }

    return;
} ## end sub add

sub load_all {
    my ($self) = @_;

    my $async = $self->_get_async;

    while ( $async->not_empty or @{ $self->get_no_request_tasks } ) {
        if ( defined( my $response = $async->next_response ) ) {
            my $request = $response->request;
            foreach my $cb ( @{ $self->get_request_tasks->{ $request->as_string } } ) {
                $cb->( $self, $self->_convert_response($response) );
            }
            delete $self->get_request_tasks->{ $request->as_string };
            $self->put_response_to( $request->as_string => $response );
        } elsif ( @{ $self->get_no_request_tasks } ) {
            my $cb = shift @{ $self->get_no_request_tasks };
            $cb->($self);
        }
    }

    return;
} ## end sub load_all

###########################################################
## Person
###########################################################

sub create_request_person {
    my ( $self, $data ) = @_;
    return GET("http://person/$data->{'object_id'}/$data->{'rid'}");
}

sub create_test_response_person {
    my ( $self, $data ) = @_;

    my $res = HTTP::Response->new;
    $res->code(200);
    $res->content(
        Mojo::JSON->new->encode( {
                first_name  => $data->{'first_name'}  // 'Helena',
                last_name   => $data->{'last_name'}   // 'Ferrua',
                profile_url => $data->{'profile_url'} // 'http://profile/helena_ferrua',
                large_image => $data->{'large_image'} // 'http://profile/helena_ferrua/large_image',
                small_image => $data->{'small_image'} // 'http://profile/helena_ferrua/small_image',
                company     => $data->{'company'}     // 'XING AG',
            },
        ),
    );

    return $res;
}

##########################################################
## Link
###########################################################

sub create_request_link {
    my ( $self, $data ) = @_;
    return GET("http://link/$data->{'object_id'}/$data->{'rid'}");
}

sub create_test_response_link {
    my ( $self, $data ) = @_;

    my $res = HTTP::Response->new;
    $res->code(200);
    $res->content(
        Mojo::JSON->new->encode( {
                'title'       => $data->{'title'}       // 'Link Title',
                'description' => $data->{'description'} // 'Link Description',
                'url'         => $data->{'url'}         // 'http://link/link_response',
                'image_url'   => $data->{'image_url'}   // 'http://link/link_response/large_image',
            },
        ),
    );

    return $res;
}

1;
