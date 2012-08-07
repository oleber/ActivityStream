package ActivityStream::Environment;
use strict;
use warnings;

use Moose;
use MooseX::FollowPBP;

use Cwd 'abs_path';
use File::Basename 'dirname';
use File::Slurp qw(read_file);
use File::Spec;
use Mojo::JSON;
use Mojolicious::Controller;
use MongoDB::Connection;
use Readonly;

use ActivityStream::AsyncUserAgent;
use ActivityStream::Data::CollectionFactory;

Readonly my $CONFIG_FILEPATH =>
      File::Spec->join( File::Spec->splitdir( dirname(__FILE__) ), '..', '..', 'config.json' );
Readonly my $ABS_CONFIG_FILEPATH => abs_path($CONFIG_FILEPATH);

die "Config file $CONFIG_FILEPATH not found" if not -f $ABS_CONFIG_FILEPATH;

has 'config_filepath' => (
    'is'      => 'ro',
    'isa'     => 'Str',
    'lazy'    => 1,
    'default' => $ABS_CONFIG_FILEPATH,
);

has 'config' => (
    'is'      => 'ro',
    'isa'     => 'HashRef',
    'lazy'    => 1,
    'default' => sub {
        return Mojo::JSON->new->decode(
            scalar( read_file( $ENV{'ACTIVITY_STREAM_CONFIG_PATH'} // shift->get_config_filepath ) ) );
    },
);

has 'db_connecton' => (
    'is'      => 'ro',
    'isa'     => 'MongoDB::Connection',
    'lazy'    => 1,
    'default' => sub { return MongoDB::Connection->new( %{ shift->get_config->{db}->{connection} } ); },
);

has 'collection_factory' => (
    'is'      => 'ro',
    'isa'     => 'ActivityStream::Data::CollectionFactory',
    'lazy'    => 1,
    'default' => sub {
        return ActivityStream::Data::CollectionFactory->new(
            'database' => shift->get_db_connecton->get_database('oleber_activity_stream') );
    },
);

has 'controller' => (
    'is'  => 'ro',
    'isa' => 'Mojolicious::Controller',
);

has 'ua' => (
    is      => 'rw',
    isa     => 'Mojo::UserAgent',
    'lazy'    => 1,
    'default' => sub {
        my ($self) = @_;
        return $self->get_controller->ua if defined $self->get_controller;
        return;
    },
);

has 'async_user_agent' => (
    'is'      => 'ro',
    'isa'     => 'ActivityStream::AsyncUserAgent',
    'lazy'    => 1,
    'default' => sub {
        my ($self) = @_;
        return ActivityStream::AsyncUserAgent->new( ua => $self->get_ua ) if defined $self->get_ua;
        return;
    },
);

has 'activity_factory' => (
    'is'      => 'ro',
    'isa'     => 'ActivityStream::API::ActivityFactory',
    'lazy'    => 1,
    'default' => sub {
        my ($self) = @_;
        my $factory = $self->get_config->{'packages'}->{'activity_factory'} // 'ActivityStream::API::ActivityFactory';
        return $factory->new( environment => $self );
    },
);

1;
