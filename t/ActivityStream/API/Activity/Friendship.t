use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

Readonly my $PKG => 'ActivityStream::API::Activity::Friendship';

use_ok($PKG);
isa_ok( $PKG => 'ActivityStream::API::Activity' );

is( $PKG->get_attribute_base_class('actor'),  'ActivityStream::API::Object::Person' );
is( $PKG->get_attribute_base_class('object'), 'ActivityStream::API::Object::Person' );

Readonly my %DATA => (
    'actor'  => { 'object_id' => 'x:person:123' },
    'verb'   => 'friendship',
    'object' => { 'object_id' => 'x:person:12' },
);

my $obj = $PKG->from_rest_request_struct( \%DATA );

is($obj->get_type, 'person:friendship:person');
cmp_deeply( $obj->to_db_struct, { %DATA, 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
cmp_deeply( $PKG->from_db_struct( $obj->to_db_struct ), $obj );
cmp_deeply( $obj->to_rest_response_struct, { %DATA, 'activity_id' => ignore, 'creation_time' => num( time, 2 ) } );
cmp_deeply( [ $obj->get_sources ], [ 'x:person:123' ] );

done_testing();
