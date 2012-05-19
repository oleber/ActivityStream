package ActivityStream::Util;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Data::UUID;
use MIME::Base64;
use POSIX qw(floor);
use Readonly;

use ActivityStream::Constants;

{
    my $root = join( ',', Data::UUID->new->create_str(), $$, time, $ActivityStream::Constants::GENERATE_ID_SECRET );
    sub generate_id {
        $root = encode_base64( reverse(pack('I',time)), '' ) . md5_base64( $root . $$ . time . $ActivityStream::Constants::GENERATE_ID_SECRET );
        $root =~ s/=//g;
        $root =~ tr/0123456789\/\+/abcdefghijkl/;
        return substr($root, 0, 20);
    }
}

Readonly my $SECONDS_IN_A_DAY => 60 * 60 * 24;

sub get_day_of {
    my ($time) = @_;
    return floor( $time / $SECONDS_IN_A_DAY );
}

1;
