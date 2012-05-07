package ActivityStream::Util;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Data::UUID;
use Readonly;

use ActivityStream::Constants;

{
    my $root = join( ',', Data::UUID->new->create_str(), $$, time, $ActivityStream::Constants::GENERATE_ID_SECRET );
    sub generate_id {
        $root = time . md5_base64( $root . $$ . time . $ActivityStream::Constants::GENERATE_ID_SECRET );
        $root =~ tr/0123456789\/\+/abcdefghijkl/;
        return $root;
    }
}

Readonly my $SECONDS_IN_A_DAY => 60 * 60 * 24;

sub get_day_of {
    my ($time) = @_;
    return int( $time / $SECONDS_IN_A_DAY );
}

1;
