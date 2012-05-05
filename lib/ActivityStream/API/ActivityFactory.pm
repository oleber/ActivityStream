package ActivityStream::API::ActivityFactory;
use Moose;
use MooseX::FollowPBP;

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

sub _structure_class {
    my ( $self, $data ) = @_;

    my @peaces;

    if ( $data->{'actor'} and $data->{'actor'}{'object_id'} and ( $data->{'actor'}{'object_id'} =~ /:(.*):/ ) ) {
        push( @peaces, $1 );
    } else {
        confess q(Can't parse actor);
    }

    push( @peaces, $data->{'verb'} );

    if ( $data->{'object'} and $data->{'object'}{'object_id'} and ( $data->{'object'}{'object_id'} =~ /:(.*):/ ) ) {
        push( @peaces, $1 );
    } else {
        confess q(Can't parse object);
    }

    if ( $data->{'target'} and $data->{'target'}{'object_id'} and ( $data->{'target'}{'object_id'} =~ /:(.*):/ ) ) {
        push( @peaces, $1 );
    }

    my $type = join( ':', @peaces );

    foreach my $mapping (@PACKAGE_FOR) {
        return $mapping->[1] if $type =~ $mapping->[0];
    }

    return;
} ## end sub _structure_class

sub instance_from_rest_request_struct {
    my ( $self, $data ) = @_;

    return $self->_structure_class($data)->from_rest_request_struct($data);
}

sub instance_from_db {
    my ( $self, $environment, $criteria ) = @_;

    my $collection_activity = $environment->get_collection_factory->collection_activity;
    my $db_activity         = $collection_activity->find_one_activity($criteria);

    if ( defined $db_activity ) {
        my $pkg = $self->_structure_class($db_activity);
        confess Dumper $db_activity if not defined $pkg;
        $pkg->from_db_struct($db_activity);
    } else {
        die ActivityStream::X::ActivityNotFound->new;    #TODO: MAKE IT AN OBJECT
    }
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;