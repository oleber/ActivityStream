use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

Readonly my $PKG => 'ActivityStream::API::Object::Person';

use_ok($PKG);
isa_ok($PKG, 'ActivityStream::API::Object');

Readonly my %DATA => ( object_id => 'x:person:125' );

my $obj = lives_ok { $PKG->new( %DATA ) };

throws_ok { $PKG->new( %DATA, object_id => 'x:link:125' ) } qr/object_id/;

done_testing();
