use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

Readonly my $PKG => 'ActivityStream::API::Object';

use_ok($PKG);

Readonly my %DATA => ( 'object_id' => 'x:person:125' );

my $obj = lives_ok { $PKG->new( %DATA ) };

dies_ok { $PKG->new( %DATA, 'object_id' => 'x:-.,:125' ) };

done_testing();
