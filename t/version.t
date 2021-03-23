#!/usr/bin/env perl

use lib 't/lib';
use Test::Most 'bail';
use Test::Search::Typesense;

my $test      = Test::Search::Typesense->new;
my $typesense = $test->typesense;

#
# collection management
#

my $version = $typesense->typesense_version;

like $version->version_string, qr/^\d+\.\d+\.\d+$/a,
  'We should be able to fetch the Typesense version';
like $version->major, qr/^\d+$/a,
  'We should be able to fetch the major Typesense version';
like $version->minor, qr/^\d+$/a,
  'We should be able to fetch the minor Typesense version';
like $version->patch, qr/^\d+$/a,
  'We should be able to fetch the patch Typesense version';

done_testing;
