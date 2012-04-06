package ActivityStream::BaseController;

use strict;
use warnings;

use Mojo::Base 'Mojolicious::Controller';

sub render_exception {
    my ( $self, @params ) = @_;

    warn $params[0];

    return $self->SUPER::render_exception(@params);
}

1;
