package ActivityStream::API::ActivityChild;
use Moose;
use Moose::Util::TypeConstraints;
use MooseX::FollowPBP;

use Carp;
use Data::Dumper;
use Scalar::Util qw(blessed);
use Storable qw(dclone);

extends 'ActivityStream::API::Activity';

has 'parent_activity_id' => (
    'is'       => 'rw',
    'isa'      => subtype( 'Str' => where {/^\w+:activity$/} ),
    'required' => 1,
);

has 'super_parent_activity_id' => (
    'is'       => 'rw',
    'isa'      => subtype( 'Str' => where {/^\w+:activity$/} ),
    'required' => 1,
);

has 'super_parent_activity' => (
    'is'  => 'rw',
    'isa' => 'ActivityStream::API::Activity',
);

sub prepare_load {
    my ( $self, $args ) = @_;

    $self->SUPER::prepare_load($args);

    # Load super_parent_activity
    my $super_parent_activity = $self->get_environment->get_activity_factory->activity_instance_from_db(
        { 'activity_id' => $self->get_super_parent_activity_id } );
    $self->set_super_parent_activity($super_parent_activity);
    $self->get_super_parent_activity->prepare_load($args);

    return;
}

sub to_simulate_rest_struct {
    my ($self) = @_;
    return {
        %{ $self->SUPER::to_simulate_rest_struct },
        'parent_activity_id'       => $self->get_parent_activity_id,
        'super_parent_activity_id' => $self->get_super_parent_activity_id
    };
}

sub to_db_struct {
    my ($self) = @_;
    return {
        %{ $self->SUPER::to_db_struct },
        'parent_activity_id'       => $self->get_parent_activity_id,
        'super_parent_activity_id' => $self->get_super_parent_activity_id
    };
}

sub _to_db_struct_likers   { return [] }
sub _to_db_struct_comments { return [] }

sub _to_rest_response_struct_likers   { return [] }
sub _to_rest_response_struct_comments { return [] }

sub to_rest_response_struct {
    my ($self) = @_;
    return {
        %{ $self->SUPER::to_rest_response_struct },
        'parent_activity_id'    => $self->get_parent_activity_id,
        'super_parent_activity' => $self->get_super_parent_activity->to_rest_response_struct,
    };
}

sub from_rest_response_struct {
    my ( $pkg, $environment, $data ) = @_;

    $data = {%$data};

    if ( defined( $data->{'super_parent_activity'} ) and not( blessed $data->{'super_parent_activity'} ) ) {
        $data->{'super_parent_activity'}
              = $environment->get_activity_factory->object_instance_from_rest_response_struct(
            $data->{'super_parent_activity'} );
    }

    if ( defined( $data->{'super_parent_activity'} ) and not( defined $data->{'super_parent_activity_id'} ) ) {
        $data->{'super_parent_activity_id'} = $data->{'super_parent_activity'}{'activity_id'};
    }

    return $pkg->SUPER::from_rest_response_struct( $environment, $data );

}

sub get_loaded_successfully {
    my ($self) = @_;
    return $self->SUPER::get_loaded_successfully
          && $self->get_super_parent_activity->get_loaded_successfully;
}

#################################################
# overwrite comments to super_parent_activity

sub set_comments {
    my ( $self, @args ) = @_;
    return $self->get_super_parent_activity->set_comments(@args);
}

sub get_comments {
    my ($self) = @_;
    if ( not defined $self->get_super_parent_activity ) {
        warn Dumper $self;
    }
    return $self->get_super_parent_activity->get_comments;
}

sub add_comment {
    my ( $self, @args ) = @_;
    return $self->get_super_parent_activity->add_comment(@args);
}

sub save_comment {
    my ( $self, $param ) = @_;
    confess( "Can't comment: " . ref($self) ) if not $self->is_commentable;

    my $comment = $self->get_super_parent_activity->save_comment( +{ %$param, 'dont_save_object_comment' => 1 } );

    $self->get_object->save_comment( $self, $param ) if $self->get_object->is_commentable;

    return $comment;
}

sub delete_comment {
    my ( $self, @args ) = @_;
    confess( "Can't comment: " . ref($self) ) if not $self->is_commentable;
    return $self->get_super_parent_activity->delete_comment(@args);
}

#################################################
# overwrite Likers to super_parent_activity

sub set_likers {
    my ( $self, @args ) = @_;
    return $self->get_super_parent_activity->set_likers(@args);
}

sub get_likers {
    my ($self) = @_;
    if ( not defined $self->get_super_parent_activity ) {
        warn Dumper $self;
    }
    return $self->get_super_parent_activity->get_likers;
}

sub add_liker {
    my ( $self, @args ) = @_;
    return $self->get_super_parent_activity->add_liker(@args);
}

sub save_liker {
    my ( $self, $param ) = @_;
    confess( "Can't liker: " . ref($self) ) if not $self->is_likeable;

    my $like = $self->get_super_parent_activity->save_liker( +{ %$param, 'dont_save_object_like' => 1 } );

    $self->get_object->save_liker( $self, $param ) if $self->get_object->is_likeable;

    return $like;
}

sub delete_liker {
    my ( $self, @args ) = @_;
    confess( "Can't liker: " . ref($self) ) if not $self->is_likeable;
    return $self->get_super_parent_activity->delete_liker(@args);
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
