package ActivityStream::Util;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Data::UUID;

{
    my $root = join( ',', Data::UUID->new->create_str(), $$, time );
    sub generate_id {
        $root = md5_base64( $root . $$ . time );
        $root =~ s/[^a-zA-Z]/a/g;
        return $root;
    }
}

1;