use 5.010001;

use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'ActivityStream',
  VERSION_FROM => 'lib/ActivityStream.pm',
  ABSTRACT     => 'ActivityStream done on Mojolicious and MongoDB',
  AUTHOR       => 'Marcos Rebelo <oleber@gmail.com>',
  LICENSE      => 'artistic_2',
  META_MERGE   => {
    requires  => {perl => '5.010001'},
    resources => {
      license     => 'http://dev.perl.org/licenses/',
      repository  => 'http://github.com/oleber/ActivityStream',
      bugtracker  => 'http://github.com/oleber/ActivityStream/issues'
    },
    no_index => {directory => ['t']}
  },
  test => {TESTS => 't/*.t t/*/*.t'}
);