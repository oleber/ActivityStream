package ActivityStream::AsyncUserAgent;
use Moose;
use MooseX::FollowPBP;

use Carp;
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

our $GLOBAL_CACHE_FOR_TEST;

has 'cache' => (
    is      => 'rw',
    isa     => 'HashRef[HTTP::Response]',
    default => sub { $GLOBAL_CACHE_FOR_TEST // {} },
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

sub add_get_web_request {
    my ( $self, $request_as_str, $cb ) = @_;

    my $request = GET( $request_as_str );

    my $key = "GET $request_as_str";

    if ( defined( my $response = $self->get_response_to($key) ) ) {
        $self->add_action( sub { $cb->( $self, $self->_convert_response($response) ) } );
    } else {
        if ( not exists $self->get_request_tasks->{$key} ) {
            $self->_get_async->add($request);
        }
        push( @{ $self->get_request_tasks->{$key} }, $cb );
    }

    return;
}

sub add_action {
    my ( $self, $cb ) = @_;

    push( @{ $self->get_no_request_tasks }, $cb );

    return;
}

sub load_all {
    my ( $self, $cb ) = @_;

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

    if ($cb) {
        $cb->();
    }

    return;
} ## end sub load_all

1;
