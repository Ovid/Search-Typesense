#!/usr/bin/env perl

use Test::Most 'bail';
use Search::Typesense;
use DDP;

# If, for some strange reason, we've still hit an existing Typesense database,
# minimize the chance of hitting a valid collection
my $collection = 'XXX_this_will_be_deleted_after_testing_XXX';

my $typesense = eval {
    Search::Typesense->new(
        use_https => 0,
        host      => 'localhost',
        port      => 7777,
        api_key   => 777,
    );
};
unless ($typesense) {
    plan( skip_all =>
"Typesense does not appear to be running. See the CONTRIBUTING.md document with this distribution."
    );
}

ok $typesense, 'We should have a typesense object';

END {
    $typesense->delete_all_collections if $typesense;
}

#
# collection management
#

lives_ok { $typesense->delete_all_collections }
'We should be able to purge all typesense collections';

my $collections = $typesense->get_collections;
eq_or_diff $collections, [],
  '... and get_collections() should tell us we have no collections';

$typesense->create_collection(
    {
        'name'          => $collection,
        'num_documents' => 0,
        'fields'        => [
            {
                'name'  => 'company_name',
                'type'  => 'string',
                'facet' => 0,
            },
            {
                'name'  => 'num_employees',
                'type'  => 'int32',
                'facet' => 0,
            },
            {
                'name'  => 'country',
                'type'  => 'string',
                'facet' => 1,
            }
        ],
        'default_sorting_field' => 'num_employees'
    }

);
$collections = $typesense->get_collections;
is @$collections, 1, 'We should have a collection after creating it';
is $collections->[0]{name}, $collection,
  '... and it should be the collection we have created';

#
# Documents
#

my $document = {
    'id'            => '124',
    'company_name'  => 'Stark Industries',
    'num_employees' => 5215,
    'country'       => 'USA'
};
my $response = $typesense->create_document( $collection, $document, );
eq_or_diff $response, $document,
  'We should be able to call create_document($collection, \%document)';

$document = {
    'id'            => '125',
    'company_name'  => 'All Around the World',
    'num_employees' => 20,
    'country'       => 'France'
};
$response = $typesense->upsert_document( $collection, $document, );
eq_or_diff $response, $document,
'We should be able to call upsert_document($collection, \%document) with a non-existent document';

$document = {
    'id'            => '125',
    'company_name'  => 'All Around the World',
    'num_employees' => 10,
    'country'       => 'France'
};
$response = $typesense->upsert_document( $collection, $document );
eq_or_diff $response, $document,
'We should be able to call upsert_document($collection, \%document) and update an existing document';

$response = $typesense->update_document($collection, 125, { num_employees => 15 });
eq_or_diff $response, { id => 125, num_employees => 15 }, 'We should be able to upsert_document()';

$response = $typesense->search(
    $collection,
    {
        q         => 'stark',
        query_by  => 'company_name',
        filter_by => 'num_employees:>100',
        sort_by   => 'num_employees:desc',
    }
);

is $response->{found}, 1, 'We should have one response found from our search()';
is $response->{out_of}, 2, '... out of the total number of records';
eq_or_diff $response->{hits}[0]{document},
  {
    company_name    => 'Stark Industries',
    'country'       => 'USA',
    'id'            => '124',
    'num_employees' => 5215
  },
  '... and should match the document we were expecting';

my $documents = [
    {
        "id"            => "124",
        "company_name"  => "Stark Industries",
        "num_employees" => 5215,
        "country"       => "US"
    },
    {
        "id"            => "125",
        "company_name"  => "Future Technology",
        "num_employees" => 1232,
        "country"       => "UK"
    },
    {
        "id"            => "126",
        "company_name"  => "Random Corp.",
        "num_employees" => 531,
        "country"       => "AU"
    },
];

lives_ok {
    $response =
      $typesense->import_documents( $collection, 'upsert', $documents );
}
'We should be able to import documents';

$response = $typesense->export_documents($collection);
eq_or_diff $response, $documents,
  '... and we should be able to export_documents($collection)';
$response = $typesense->export_documents('compani');
ok !defined $response,
'... but trying to export documents from a non-existing collection should fail';

done_testing;
