package ActivityStream::Util;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Data::UUID;

{
    my $root = join( ',', Data::UUID->new->create_str(), $$, time );
    sub generate_id {
        $root = time . md5_base64( $root . $$ . time );
        $root =~ tr/0123456789\/\+/abcdefghijkl/;
        return $root;
    }
}

1;