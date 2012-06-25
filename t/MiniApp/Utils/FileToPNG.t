#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use File::Basename 'dirname';
use File::Glob qw(bsd_glob);
use Readonly;
use Try::Tiny;

Readonly my $PKG => 'MiniApp::Utils::FileToPNG';
use_ok($PKG);

my $path = dirname(__FILE__);

print "PATH: $path";

my $directory = File::Spec->join( $path, 'FileToPNG' );

{
    note('File not found');
    my $not_existing_filepath = File::Spec->join( $directory, 'not existing.pptx' );
    ok( not -e -f $not_existing_filepath );
    throws_ok( sub { $PKG->new( 'filepath' => $not_existing_filepath ) },
        qr/File not found: \Q$not_existing_filepath\E/ );
}

{
    my @good_files = bsd_glob( File::Spec->join( $directory, '*' ) );
    @good_files = grep { not /\.dll$/ } @good_files;
    is( scalar(@good_files), 10 );

    foreach my $filepath (@good_files) {
        note("converting $filepath");
        try {
            my $obj = MiniApp::Utils::FileToPNG->new( 'filepath' => $filepath );
            is( $obj->get_filepath, $filepath );

            lives_ok { $obj->convert };
            ok( -f -r $obj->get_converted_filepath );
            isnt( $obj->get_converted_filepath, $filepath );

            like( $obj->get_converted_filepath, qr/\.png$/ );
        }
        catch {
            fail($_);
        };
    }
}

{
    my @bad_files = bsd_glob( File::Spec->join( $directory, '*.{dll}' ) );
    is( scalar(@bad_files), 1 );

    foreach my $filepath (@bad_files) {
        note("converting $filepath");
        my $obj;
        lives_ok { $obj = MiniApp::Utils::FileToPNG->new( 'filepath' => $filepath ) };
        throws_ok { $obj->convert } qr/Can't convert file: \Q$filepath\E/;
    }
}
