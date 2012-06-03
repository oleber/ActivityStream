#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojolicious;
use Readonly;
use Time::Local;

Readonly my $PKG => 'ActivityStream::AsyncUserAgent::MongoUserAgent';

use_ok $PKG;

{

    package ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp;
    use Mojo::Base 'Mojolicious';
    use Try::Tiny;

    sub startup {
        my $self = shift;

        $self->hook(
            around_dispatch => sub {
                my ( $next, $c ) = @_;

                try { $next->() }
                catch {
                    my $exception = $_;
                    warn "EXCEPTION: $exception";
                    die $exception;
                };
            },
        );

        return;
    }
}

{
    note('nothing to do');

    my $t = Test::Mojo->new( ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp->new() );

    $t->app->routes->get('/test_call')->to(
        'cb' => sub {
            my $c = shift;
            my $ua = $PKG->new( 'ua' => $c->ua );
            $ua->load_all( sub { $c->render_json( ['test_value'] ) } );
        },
    );

    $t->get_ok('/test_call')->json_content_is( ['test_value'] );
}

{
    note('do static action');

    my $t = Test::Mojo->new( ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp->new() );

    $t->app->routes->get('/test_call')->to(
        'cb' => sub {
            my $c = shift;

            my $ua = $PKG->new( 'ua' => $c->ua );

            my $return;
            $ua->add_action( sub { $return = ['test_value']; } );

            $ua->load_all( sub { $c->render_json($return); } );
        },
    );

    $t->get_ok('/test_call')->json_content_is( ['test_value'] );
}

{
    note('do single web_request');

    my $t = Test::Mojo->new( ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp->new() );

    my $return;

    $t->app->routes->get('/call')->to( 'cb' => sub { shift->render_json( ['test_value'] ); } );

    $t->app->routes->get('/test_call')->to(
        'cb' => sub {
            my $c = shift;

            my $return;

            my $ua = $PKG->new( 'ua' => $c->ua );

            $ua->add_get_web_request( '/call', sub { $return = shift->res->json } );
            $ua->load_all( sub { $c->render_json($return) } );
        },
    );

    $t->get_ok('/test_call')->json_content_is( ['test_value'] );
}

{
    note('do cached web_request');

    my $t = Test::Mojo->new( ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp->new() );

    my $callcount;

    $t->app->routes->get('/call')->to( 'cb' => sub { shift->render_json( ['test_value'] ); $callcount++; } );

    $t->app->routes->get('/test_call')->to(
        'cb' => sub {
            my $c = shift;

            my $return;

            my $ua = $PKG->new( 'ua' => $c->ua );

            $ua->add_get_web_request( '/call', sub { $return->{'call_1'} = shift->res->json; } );
            $ua->add_get_web_request( '/call', sub { $return->{'call_2'} = shift->res->json; } );

            $ua->load_all( sub { $c->render_json($return); } );
        },
    );

    $t->get_ok('/test_call')->json_content_is( { 'call_1' => ['test_value'], 'call_2' => ['test_value'] } );
    is( $callcount, 1 );
}

{
    note('do double/cached web_request');

    my $t = Test::Mojo->new( ActivityStream::AsyncUserAgent::MongoUserAgent::TestApp->new() );

    my $callcount;

    $t->app->routes->get('/call_1')->to( 'cb' => sub { shift->render_json( ['test_value_1'] ); $callcount++; } );
    $t->app->routes->get('/call_2')->to( 'cb' => sub { shift->render_json( ['test_value_2'] ); $callcount++; } );

    $t->app->routes->get('/test_call')->to(
        'cb' => sub {
            my $c = shift;

            my $return;

            my $ua = $PKG->new( 'ua' => $c->ua );

            $ua->add_get_web_request( '/call_1', sub { $return->{'call_1_1'} = shift->res->json; } );
            $ua->add_get_web_request( '/call_1', sub { $return->{'call_1_2'} = shift->res->json; } );
            $ua->add_get_web_request( '/call_2', sub { $return->{'call_2_1'} = shift->res->json; } );
            $ua->add_get_web_request( '/call_2', sub { $return->{'call_2_2'} = shift->res->json; } );

            $ua->load_all( sub { $c->render_json($return); } );
        },
    );

    $t->get_ok('/test_call')->json_content_is( {
            'call_1_1' => ['test_value_1'],
            'call_1_2' => ['test_value_1'],
            'call_2_1' => ['test_value_2'],
            'call_2_2' => ['test_value_2'],
    } );

    is( $callcount, 2 );
}

done_testing;
