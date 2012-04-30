use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Mojo::JSON;
use Readonly;

use ActivityStream::Environment;
use Storable qw(dclone);

Readonly my $PKG => 'ActivityStream::API::Object::Link';

use_ok($PKG);
isa_ok( $PKG, 'ActivityStream::API::Object' );

Readonly my %DATA => ( 'object_id' => 'x:link:125' );
Readonly my %DATA_REQUEST => ( %DATA, 'rid' => 'rid_1' );
Readonly my %DATA_RESPONSE => (
    %DATA,
    'title'         => 'Link Title',
    'description'   => 'Link Description',
    'url'           => 'http://link/link_response',
    'image_url'     => 'http://link/link_response/large_image',
);

my $environment      = ActivityStream::Environment->new;
my $async_user_agent = $environment->get_async_user_agent;

my $request_as_string = $async_user_agent->create_request_link( \%DATA_REQUEST )->as_string;

{
    note('Check object_id');

    throws_ok { $PKG->new( %DATA, 'object_id' => 'x:xpto:125' ) } qr/object_id/;
}

{
    note('Test DB');
    my $obj = $PKG->new(%DATA);
    is( $obj->get_type, 'link' );

    cmp_deeply( $obj->to_db_struct,                         \%DATA );
    cmp_deeply( $PKG->from_db_struct( $obj->to_db_struct ), $obj );
}

{
    note('Test Successfull response');

    my $obj = $PKG->new(%DATA);

    $async_user_agent->put_response_to( $request_as_string,
        $async_user_agent->create_test_response_link( { %DATA_RESPONSE, 'rid' => 'rid_1' } ),
    );

    $obj->prepare_load( $environment, { 'rid' => 'rid_1' } );
    $async_user_agent->load_all;

    cmp_deeply( $obj->to_rest_response_struct, \%DATA_RESPONSE ) or warn Dumper $obj->to_rest_response_struct;
    ok( $obj->get_loaded_successfully );
}

{
    note('Test not Successfull response');

    my $obj = $PKG->new(%DATA);

    $async_user_agent->put_response_to( $request_as_string, HTTP::Response->new(400) );

    $obj->prepare_load( $environment, { 'rid' => 'rid_1' } );
    $async_user_agent->load_all;

    dies_ok( sub { $obj->to_rest_response_struct } );
    ok( not $obj->get_loaded_successfully );
}

done_testing();
