package MiniApp::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

extends 'ActivityStream::API::ActivityFactory';

use Carp;
use Data::Dumper;
use Readonly;

use MiniApp::API::Activity::PersonShareStatus;
use MiniApp::API::Activity::PersonShareFile;
use MiniApp::API::Activity::PersonShareLink;

use MiniApp::API::Activity::PersonRecommendFile;
use MiniApp::API::Activity::PersonCommentFile;
use MiniApp::API::Activity::PersonLikeFile;

use MiniApp::API::Activity::PersonCommentLink;
use MiniApp::API::Activity::PersonLikeLink;
use MiniApp::API::Activity::PersonRecommendLink;

use MiniApp::API::Thing::Person;
use MiniApp::API::Thing::Status;
use MiniApp::API::Thing::File;

sub activity_package_for {
    return (
        [ qr/^ma_person:share:ma_status$/   => 'MiniApp::API::Activity::PersonShareStatus' ],
        [ qr/^ma_person:share:ma_file$/     => 'MiniApp::API::Activity::PersonShareFile' ],
        [ qr/^ma_person:share:ma_link$/     => 'MiniApp::API::Activity::PersonShareLink' ],
        [ qr/^ma_person:comment:ma_link$/   => 'MiniApp::API::Activity::PersonCommentLink' ],
        [ qr/^ma_person:comment:ma_file$/   => 'MiniApp::API::Activity::PersonCommentFile' ],
        [ qr/^ma_person:like:ma_link$/      => 'MiniApp::API::Activity::PersonLikeLink' ],
        [ qr/^ma_person:like:ma_file$/      => 'MiniApp::API::Activity::PersonLikeFile' ],
        [ qr/^ma_person:recommend:ma_link$/ => 'MiniApp::API::Activity::PersonRecommendLink' ],
        [ qr/^ma_person:recommend:ma_file$/ => 'MiniApp::API::Activity::PersonRecommendFile' ],
    );
}

sub object_package_for {
    return (
        [ qr/^ma_person$/ => 'MiniApp::API::Thing::Person' ],
        [ qr/^ma_status$/ => 'MiniApp::API::Thing::Status' ],
        [ qr/^ma_file$/   => 'MiniApp::API::Thing::File' ],
        [ qr/^ma_link$/   => 'MiniApp::API::Thing::Link' ],
    );
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
