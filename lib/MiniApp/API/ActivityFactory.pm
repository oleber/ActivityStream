package MiniApp::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

extends 'ActivityStream::API::ActivityFactory';

use Carp;
use Data::Dumper;
use Readonly;

use ActivityStream::API::Activity::Friendship;
use ActivityStream::API::Activity::LinkShare;
use ActivityStream::X::ActivityNotFound;

Readonly my @PACKAGE_FOR => (
    [ qr/person:friendship:person/ => 'ActivityStream::API::Activity::Friendship' ],
    [ qr/person:share:link/        => 'ActivityStream::API::Activity::LinkShare' ],
);

sub package_for {
    return @PACKAGE_FOR;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
