package MiniApp::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

extends 'ActivityStream::API::ActivityFactory';

use Carp;
use Data::Dumper;
use Readonly;

use MiniApp::API::Activity::Status;
use MiniApp::API::Activity::PersonShareFile;
use MiniApp::API::Activity::PersonRecommendFile;
use MiniApp::API::Activity::PersonShareLink;
use MiniApp::API::Activity::PersonRecommendLink;

use MiniApp::API::Object::Person;
use MiniApp::API::Object::StatusMessage;
use MiniApp::API::Object::File;

sub activity_package_for {
    return (
        [ qr/^ma_person:share:ma_status$/   => 'MiniApp::API::Activity::Status' ],
        [ qr/^ma_person:share:ma_file$/     => 'MiniApp::API::Activity::PersonShareFile' ],
        [ qr/^ma_person:share:ma_link$/     => 'MiniApp::API::Activity::PersonShareLink' ],
        [ qr/^ma_person:recommend:ma_link$/ => 'MiniApp::API::Activity::PersonRecommendLink' ],
        [ qr/^ma_person:recommend:ma_file$/ => 'MiniApp::API::Activity::PersonRecommendFile' ],
    );
}

sub object_package_for {
    return (
        [ qr/^ma_person$/ => 'MiniApp::API::Object::Person' ],
        [ qr/^ma_status$/ => 'MiniApp::API::Object::StatusMessage' ],
        [ qr/^ma_file$/   => 'MiniApp::API::Object::File' ],
        [ qr/^ma_link$/   => 'MiniApp::API::Object::Link' ],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
