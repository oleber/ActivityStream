package ActivityStream::AsyncUserAgent::MongoUserAgent;
use Moose;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use HTTP::Async;

use Mojo::Message::Response;
use Mojolicious::Controller;
use Try::Tiny;

has 'ua' => (
    is      => 'rw',
    isa     => 'Mojo::UserAgent',
);

has 'delay' => (
    is      => 'rw',
    isa     => 'Mojo::IOLoop::Delay',
    lazy    => 1,
    default => sub {
        my ($self) = @_;

        my $delay = Mojo::IOLoop->delay(
            sub {
                my ( $delay, @results ) = @_;
                if ( defined $self->get_finalize ) {
                    $self->get_finalize->( $self, @results );
                }
            } );

        # activate the delay
        $delay->begin;
        Mojo::IOLoop->timer(
            0 => sub {
                $delay->end;
                return;
            } );

        return $delay;
    } );

has 'finalize' => (
    is  => 'rw',
    isa => 'CodeRef',
);

has 'request_tasks' => (
    is      => 'rw',
    isa     => 'HashRef[ArrayRef[CODE]]',
    default => sub { {} },
);

our $GLOBAL_CACHE_FOR_TEST;

has 'cache' => (
    is      => 'rw',
    isa     => 'HashRef',
    default => sub { $GLOBAL_CACHE_FOR_TEST // {} },
    traits  => ['Hash'],
    handles => {
        put_response_to => 'set',
        get_response_to => 'get',
    },
);

sub add_get_web_request {
    my ( $self, $request, $cb ) = @_;

    my $key = "GET $request";

    if ( not defined $self->get_response_to($key) ) {

        $self->get_request_tasks->{$key} //= [];

        if ( not @{ $self->get_request_tasks->{$key} } ) {
            $self->get_delay->begin;

            confess "not defined ua" if not defined $self->get_ua;

            $self->get_ua->get(
                $request => sub {
                    my ( $ua, $tx ) = @_;

                    $self->put_response_to( $key, $tx );

                    foreach my $request_task ( @{ $self->get_request_tasks->{$key} } ) {
                        $self->add_action( sub { $request_task->( $self->get_response_to($key) ) } );
                    }

                    $self->get_request_tasks->{$key} = [];    # important to remove circularity

                    $self->get_delay->end;
                },
            );
        }

        push( @{ $self->get_request_tasks->{$key} }, $cb );
    } else {
        $self->add_action( sub { $cb->( $self->get_response_to($key) ) } );
    }

    return;
} ## end sub add_get_web_request

sub add_action {
    my ( $self, $cb ) = @_;

    $self->get_delay->begin;
    return Mojo::IOLoop->timer(
        0 => sub {
            my $exception;

            try { $cb->() } catch { $exception = $_; warn $exception; };

            $self->get_delay->end;
            die $exception if defined $exception;
        },
    );
    }

sub load_all {
    my ( $self, $cb ) = @_;

    $self->get_delay;

    if ( defined $cb ) {
        $self->set_finalize($cb);
    }

    Mojo::IOLoop->start if not Mojo::IOLoop->is_running;

    return;
}

1;
