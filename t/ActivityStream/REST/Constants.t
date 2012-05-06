use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Readonly;

Readonly my $PKG => 'ActivityStream::REST::Constants';

use_ok $PKG;

my %ERROR_MESSAGES = map { $_ => ${ $ActivityStream::REST::Constants::{$_} } }
      grep {/ERROR_MESSAGE_/} keys(%ActivityStream::REST::Constants::);

cmp_deeply(
    \%ERROR_MESSAGES,
    {

        # > RID
        'ERROR_MESSAGE_BAD_RID'        => 'BAD_RID',
        'ERROR_MESSAGE_NO_RID_DEFINED' => 'NO_RID_DEFINED',

        # > ACTIVITY
        'ERROR_MESSAGE_ACTIVITY_NOT_FOUND' => 'ACTIVITY_NOT_FOUND',

        # > ACTIVITY > LIKE
        'ERROR_MESSAGE_LIKE_NOT_FOUND' => 'LIKE_NOT_FOUND',
    },
);

done_testing();
