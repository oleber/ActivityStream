package ActivityStream::API::Activity;
use Moose;
use MooseX::FollowPBP;

use Data::Dumper;
use List::MoreUtils qw(any);
use Scalar::Util qw(blessed);

use ActivityStream::API::ActivityLike;
use ActivityStream::API::ActivityComment;
use ActivityStream::API::Object;
use ActivityStream::Util;
use ActivityStream::X::CommentNotFound;
use ActivityStream::X::LikerNotFound;

has 'activity_id' => (
    'is'      => 'rw',
    'isa'     => 'Str',
    'default' => sub { 'activity:' . ActivityStream::Util::generate_id },
);

has 'creation_time' => (
    'is'      => 'rw',
    'isa'     => 'Int',
    'default' => sub { time() },
);

has 'actor' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Object',
    'required' => 1,
);

has 'verb' => (
    'is'       => 'rw',
    'isa'      => 'Str',
    'required' => 1,
);

has 'object' => (
    'is'       => 'rw',
    'isa'      => 'ActivityStream::API::Object',
    'required' => 1,
);

has 'target' => (
    'is'  => 'rw',
    'isa' => 'Maybe[ActivityStream::API::Object]'
);

has 'visibility' => (
    'is'      => 'rw',
    'isa'     => 'Bool',
    'default' => 1
);

has 'loaded_successfully' => (
    'is'  => 'rw',
    'isa' => 'Bool',
);

has 'likers' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[ActivityStream::API::ActivityLike]',
    'default' => sub { [] },
    'traits'  => ['Array'],
    'handles' => { 'add_like' => 'push' },
);

has 'comments' => (
    'is'      => 'rw',
    'isa'     => 'ArrayRef[ActivityStream::API::ActivityComment]',
    'default' => sub { [] },
    'traits'  => ['Array'],
    'handles' => { 'add_comment' => 'push' },
);

has 'loaded_successfully' => (
    'is'  => 'rw',
    'isa' => 'Maybe[Bool]',
);

around BUILDARGS => sub {
    my ( $orig, $class, @args ) = @_;

    my $args = $class->$orig(@args);

    foreach my $value ( @{ $args->{'likers'} // [] } ) {
        $value = ActivityStream::API::ActivityLike->new($value);    # change inline
    }

    foreach my $value ( @{ $args->{'comments'} // [] } ) {
        $value = ActivityStream::API::ActivityComment->new($value);    # change inline
    }

    return $args;
};

sub is_likeable     { return 0 }
sub is_commentable  { return 0 }
sub is_recomendable { return 0 }

sub to_db_struct {
    my ($self) = @_;
    my %data = (
        'activity_id'   => $self->get_activity_id,
        'actor'         => $self->get_actor->to_db_struct,
        'verb'          => $self->get_verb,
        'object'        => $self->get_object->to_db_struct,
        'visibility'    => $self->get_visibility,
        'likers'        => [ map { $_->to_db_struct } @{ $self->get_likers } ],
        'comments'      => [ map { $_->to_db_struct } @{ $self->get_comments } ],
        'creation_time' => $self->get_creation_time,
    );

    if ( defined $self->get_target ) {
        $data{'target'} = $self->get_target->to_db_struct;
    }

    return \%data;
}

sub save_in_db {
    my ( $self, $environment ) = @_;

    my $collection_source   = $environment->get_collection_factory->collection_source;
    my $collection_activity = $environment->get_collection_factory->collection_activity;

    $collection_activity->upsert_activity( { 'activity_id' => $self->get_activity_id }, $self->to_db_struct );

    foreach my $source ( $self->get_sources ) {
        $collection_source->upsert_source(
            { 'source_id' => $source, 'day' => ActivityStream::Util::get_day_of( $self->get_creation_time ) },
            {
                '$set' => {
                    sprintf( 'activity.%s', $self->get_activity_id ) => $self->get_creation_time,
                    'status' => ActivityStream::Util::generate_id,
                }
            },
        );
    }

    return $self;
} ## end sub save_in_db

sub save_visibility {
    my ( $self, $environment, $visibility ) = @_;

    my $collection_activity = $environment->get_collection_factory->collection_activity;

    $collection_activity->upsert_activity(
        { 'activity_id' => $self->get_activity_id },
        { '$set'        => { 'visibility' => $visibility } },
    );

    $self->set_visibility($visibility);

    return;
}

sub to_rest_response_struct {
    my ($self) = @_;

    confess sprintf( "Activity '%s' didn't load correctly", $self->get_activity_id )
          if not $self->get_loaded_successfully;

    my %data = (
        'activity_id'   => $self->get_activity_id,
        'actor'         => $self->get_actor->to_rest_response_struct,
        'verb'          => $self->get_verb,
        'object'        => $self->get_object->to_rest_response_struct,
        'likers'        => [ map { $_->to_rest_response_struct } @{ $self->get_likers } ],
        'comments'      => [ map { $_->to_rest_response_struct } @{ $self->get_comments } ],
        'creation_time' => $self->get_creation_time,
    );

    if ( defined $self->get_target ) {
        $data{'target'} = $self->get_target->to_rest_response_struct;
    }

    return \%data;
} ## end sub to_rest_response_struct

sub get_sources {
    my ($self) = @_;
    return ( $self->get_actor->get_object_id );
}

sub get_type {
    my ($self) = @_;
    return join( ':',
        $self->get_actor->get_type,
        $self->get_verb,
        $self->get_object->get_type,
        ( $self->get_target ? $self->get_target->get_type : () ),
    );
}

sub from_db_struct {
    my ( $pkg, $data ) = @_;

    my %data = %$data;

    $data{'actor'}  = $pkg->get_attribute_base_class('actor')->from_db_struct( $data{'actor'} );
    $data{'object'} = $pkg->get_attribute_base_class('object')->from_db_struct( $data{'object'} );

    if ( defined $data{'target'} ) {
        $data{'target'} = $pkg->get_attribute_base_class('target')->from_db_struct( $data{'target'} );
    }

    return $pkg->new(%data);
}

sub from_rest_request_struct {
    my ( $pkg, $data ) = @_;

    my %data = %$data;

    $data{'actor'}  = $pkg->get_attribute_base_class('actor')->from_rest_request_struct( $data{'actor'} );
    $data{'object'} = $pkg->get_attribute_base_class('object')->from_rest_request_struct( $data{'object'} );

    if ( defined $data{'target'} ) {
        $data{'target'} = $pkg->get_attribute_base_class('target')->from_rest_request_struct( $data{'target'} );
    }

    return $pkg->new(%data);
}

sub get_attribute_base_class {
    my ( $pkg, $name ) = @_;

    my $type_constraint = $pkg->meta->find_attribute_by_name($name)->type_constraint;

    if ( $type_constraint->isa('Moose::Meta::TypeConstraint::Parameterized') ) {
        $type_constraint = $type_constraint->type_parameter;
    }

    return $type_constraint->name;
}

sub prepare_load {
    my ( $self, $environment, $args ) = @_;

    $self->prepare_load_comments( $environment, $args );
    $self->prepare_load_likers( $environment, $args );

    $self->prepare_load_actor( $environment, $args );
    $self->prepare_load_object( $environment, $args );
    $self->prepare_load_target( $environment, $args );

    return;
}

sub prepare_load_actor {
    my ( $self, $environment, $args ) = @_;

    $self->get_actor->prepare_load( $environment, $args );

    return;
}

sub prepare_load_object {
    my ( $self, $environment, $args ) = @_;

    $self->get_object->prepare_load( $environment, $args );

    return;
}

sub prepare_load_target {
    my ( $self, $environment, $args ) = @_;

    $self->get_target->prepare_load( $environment, $args ) if defined $self->get_target;

    return;
}

use List::Util qw(max);

sub prepare_load_comments {
    my ( $self, $environment, $args ) = @_;

    my $max_comments = $args->{'max_comments'};

    $max_comments ||= @{ $self->get_comments };    # default and 0 go to all

    foreach my $index ( max( 0, @{ $self->get_comments } - $max_comments ) .. ( @{ $self->get_comments } - 1 ) ) {
        $self->get_comments->[$index]->prepare_load( $environment, $args );
    }

    return;
}

sub prepare_load_likers {
    my ( $self, $environment, $args ) = @_;

    my $max_likers = $args->{'max_likers'};

    $max_likers ||= @{ $self->get_likers };    # default and 0 go to all

    foreach my $index ( max( 0, @{ $self->get_likers } - $max_likers ) .. ( @{ $self->get_likers } - 1 ) ) {
        $self->get_likers->[$index]->prepare_load( $environment, $args );
    }

    return;
}

sub load {
    my ( $self, $environment, $args ) = @_;

    $self->prepare_load( $environment, $args );
    return $environment->get_async_user_agent->load_all;
}

sub has_fully_loaded_successfully {
    my ($self) = @_;

    return
             $self->get_loaded_successfully
          && $self->actor_loaded_successfully
          && $self->object_loaded_successfully
          && $self->target_loaded_successfully;
}

sub actor_loaded_successfully {
    my ($self) = @_;

    return $self->get_actor->get_loaded_successfully;
}

sub object_loaded_successfully {
    my ($self) = @_;

    return $self->get_object->get_loaded_successfully;
}

sub target_loaded_successfully {
    my ($self) = @_;

    return 1 if not defined $self->get_target;

    return $self->get_actor->get_loaded_successfully;
}

sub save_like {
    my ( $self, $environment, $param ) = @_;

    $self->set_loaded_successfully(undef);

    confess( "Can't like: " . ref($self) ) if not $self->is_likeable;

    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $activity_like = blessed($param) ? $param : ActivityStream::API::ActivityLike->new($param);

    $self->add_like($activity_like);

    $collection_activity->update_activity(
        { 'activity_id' => $self->get_activity_id },
        { '$push'       => { 'likers' => $activity_like->to_db_struct } },
    );

    return $activity_like;
} ## end sub save_like

sub delete_liker {
    my ( $self, $environment, $param ) = @_;

    $self->set_loaded_successfully(undef);

    confess( "Can't liker: " . ref($self) ) if not $self->is_likeable;

    my $like_id = $param->{'like_id'};
    my @new_likers = grep { $_->get_like_id ne $like_id } @{ $self->get_likers };

    die ActivityStream::X::LikerNotFound->new if scalar(@new_likers) == scalar( @{ $self->get_likers } );

    my $collection_activity = $environment->get_collection_factory->collection_activity;

    $self->set_likers( \@new_likers );

    $collection_activity->update_activity(
        { 'activity_id' => $self->get_activity_id },
        { '$set'        => { 'likers' => [ map { $_->to_db_struct } @{ $self->get_likers } ] } },
    );

    return;
} ## end sub delete_liker

sub save_comment {
    my ( $self, $environment, $param ) = @_;

    $self->set_loaded_successfully(undef);

    confess( "Can't comment: " . ref($self) ) if not $self->is_commentable;

    my $collection_activity = $environment->get_collection_factory->collection_activity;

    my $activity_comment = blessed($param) ? $param : ActivityStream::API::ActivityComment->new($param);

    $self->add_comment($activity_comment);

    $collection_activity->update_activity(
        { 'activity_id' => $self->get_activity_id },
        { '$push'       => { 'comments' => $activity_comment->to_db_struct } },
    );

    return $activity_comment;
} ## end sub save_comment

sub delete_comment {
    my ( $self, $environment, $param ) = @_;

    $self->set_loaded_successfully(undef);

    confess( "Can't comment: " . ref($self) ) if not $self->is_commentable;

    my $comment_id = $param->{'comment_id'};
    my @new_comments = grep { $_->get_comment_id ne $comment_id } @{ $self->get_comments };

    die ActivityStream::X::CommentNotFound->new if scalar(@new_comments) == scalar( @{ $self->get_comments } );

    my $collection_activity = $environment->get_collection_factory->collection_activity;

    $self->set_comments( \@new_comments );

    $collection_activity->update_activity(
        { 'activity_id' => $self->get_activity_id },
        { '$set'        => { 'comments' => [ map { $_->to_db_struct } @{ $self->get_comments } ] } },
    );

    return;
} ## end sub delete_comment

sub preload_filter_pass {
    my ( $self, $filter ) = @_;

    return if not $self->get_visibility;

    return if any { $self->get_activity_id eq $_ } @{ $filter->get_ignore_activities };

    foreach my $source ( $self->get_sources ) {
        return if any { $source eq $_ } @{ $filter->get_ignore_sources };
    }

    return 1;
}

__PACKAGE__->meta->make_immutable;
no Moose;

1;
