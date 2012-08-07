#!/usr/bin/perl

use Mojo::Base -strict;

use Test::Most;
use Test::Mojo;

use Data::Dumper;
use Readonly;

use ActivityStream::Environment;

my $t = Test::Mojo->new( Mojolicious->new );
Readonly my $environment => ActivityStream::Environment->new( ua => $t->ua );

Readonly my $PKG => 'ActivityStream::API::Thing';

use_ok($PKG);

Readonly my %DATA => ( 'object_id' => 'person:125' );

my $obj = lives_ok { $PKG->new( { 'environment' => $environment, %DATA } ) };

dies_ok { $PKG->new( 'environment' => $environment, %DATA, 'object_id' => 'x:-.,:125' ) };

done_testing;
