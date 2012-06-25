package MiniApp::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

extends 'ActivityStream::API::ActivityFactory';

use Carp;
use Data::Dumper;
use Readonly;

use MiniApp::API::Activity::Status;
use MiniApp::API::Activity::PersonShareFile;

use MiniApp::API::Object::Person;
use MiniApp::API::Object::StatusMessage;
use MiniApp::API::Object::File;

sub activity_package_for {
    return (
        [ qr/ma_person:share:ma_status/ => 'MiniApp::API::Activity::Status' ],
        [ qr/ma_person:share:ma_file/   => 'MiniApp::API::Activity::PersonShareFile' ],
    );
}

sub object_package_for {
    return (
        [ qr/^ma_person$/ => 'MiniApp::API::Object::Person' ],
        [ qr/^ma_status$/ => 'MiniApp::API::Object::StatusMessage' ],
        [ qr/^ma_file$/   => 'MiniApp::API::Object::File' ],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
