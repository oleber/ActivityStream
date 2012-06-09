package MiniApp::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

extends 'ActivityStream::API::ActivityFactory';

use Carp;
use Data::Dumper;
use Readonly;

use MiniApp::API::Activity::Status;
use ActivityStream::X::ActivityNotFound;

Readonly my @PACKAGE_FOR => ( [ qr/ma_person:share:ma_status/ => 'MiniApp::API::Activity::Status' ], );

sub package_for {
    return @PACKAGE_FOR;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
