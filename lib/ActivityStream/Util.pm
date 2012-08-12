package ActivityStream::Util;

use strict;
use warnings;

use Digest::MD5 qw(md5_base64);
use Data::UUID;
use MIME::Base64 qw(encode_base64);
use POSIX qw(floor);
use Readonly;

use ActivityStream::Constants;

{
    my $root = join( ',', Data::UUID->new->create_str(), $$, time, $ActivityStream::Constants::GENERATE_ID_SECRET );

    sub generate_id {
        $root = md5_base64( $root . $$ . time . $ActivityStream::Constants::GENERATE_ID_SECRET )
              . encode_base64( reverse( pack( 'I', time ) ), '' );
        $root =~ s/=//g;
        $root =~ tr/0123456789\/\+/abcdefghijkl/;
        return substr( $root, 0, 20 );
    }
}

sub calc_hash {
    my $hash = 0;
    foreach ( split //, shift ) {
        $hash %= 2**25 + 1;
        $hash = $hash * 33 + ord($_);
    }
    return $hash;
}

sub split_id {
    my ($str) = @_;
    my %data;
    @data{ 'id', 'type' } = split( /:/, $str );
    return \%data;
}

1;
