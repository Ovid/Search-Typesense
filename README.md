# NAME

Search::Typesense - Perl interface to Typesense search engine.

# SYNOPSIS

    my $typesense = Search::Typesense->new(
        use_https => $bool,
        host      => $host,
        port      => $port,
    );
    
    my $results = $typesense->search(
        $collection_name,
        { q => 'Search String' },
    );
    if ( $results->{found} ) {
        foreach my $hit ( @{ $results->{hits} } ) {
            ...;
        }
    }

# DESCRIPTION

This is a simple interface to the [Typesense](https://typesense.org/) search
engine. Most methods will do one of three things:

- Return results as defined in the Typesense documentation (listed per section)
- Return nothing if Typesense returns a 404.
- `croak` if Typesense returns an error.

# VERSION

Version 0.01

# METHODS

## `assert_is_running`

    $typesense->assert_is_running;

This does nothing if we can connect to Typesense. Otherwise, this method will
`croak` with a message explaining the error.

## `get_collections`

    if ( my $collections = $typesense->get_collections ) {
        # returns all collections
    }
    if ( my $collections = $typesense->get_collections($collection_name) ) {
        # returns collection matching $collection_name, if any
    }

Response shown at [https://typesense.org/docs/0.19.0/api/#retrieve-collection](https://typesense.org/docs/0.19.0/api/#retrieve-collection)

## `delete_collection`

    my $response = $typesense->delete_collection($collection_name);

Response shown at [https://typesense.org/docs/0.19.0/api/#drop-collection](https://typesense.org/docs/0.19.0/api/#drop-collection)

## `create_collection`

    my $collection = $typesense->create_collection(\%definition);

Arguments and response as shown at
[https://typesense.org/docs/0.19.0/api/#create-collection](https://typesense.org/docs/0.19.0/api/#create-collection)

## `create_document`

    my $document = $typesense->create_document($collection, \%data);

Arguments and response as shown at [https://typesense.org/docs/0.19.0/api/#index-document](https://typesense.org/docs/0.19.0/api/#index-document)

## `upsert_document`

    my $document = $typesense->upsert_document($collection, \%data);

Arguments and response as shown at [https://typesense.org/docs/0.19.0/api/#upsert](https://typesense.org/docs/0.19.0/api/#upsert)

## `update_document`

    my $document = $typesense->update_document($collection, $document_id, \%data);

Arguments and response as shown at [https://typesense.org/docs/0.19.0/api/#update-document](https://typesense.org/docs/0.19.0/api/#update-document)

## `delete_document`

    my $document = $typesense->delete_document($collection_name, $document_id);

Arguments and response as shown at [https://typesense.org/docs/0.19.0/api/#delete-document](https://typesense.org/docs/0.19.0/api/#delete-document)

## `search`

    my $results = $typesense->search($collection_name, {q => 'London'});

The parameters for `$query` are defined at
[https://typesense.org/docs/0.19.0/api/#search-collection](https://typesense.org/docs/0.19.0/api/#search-collection), as are the results.

Unlike other methods, if we find nothing, we still return the data structure
(instead of `undef` instead of a 404 exception).

## `export_documents`

    my $export = $typesense->export_documents($collection_name);

Response as shown at [https://typesense.org/docs/0.19.0/api/#export-documents](https://typesense.org/docs/0.19.0/api/#export-documents)

(An arrayref of hashrefs)

## `import_documents`

     my $response = $typesense->import_documents(
       $collection_name,
       $action,
       \@documents,
    );

Response as shown at [https://typesense.org/docs/0.19.0/api/#import-documents](https://typesense.org/docs/0.19.0/api/#import-documents)

`$action` must be one of `create`, `update`, or `upsert`.

## `purge`

    $typesense->purge;

Deletes everything from Typsense. **Use with caution**!

# AUTHOR

Curtis "Ovid" Poe, `<ovid at allaroundtheworld.fr>`

# BUGS

Please report any bugs or feature requests to `bug-search-typesense at rt.cpan.org`, or through
the web interface at [https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Search-Typesense](https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Search-Typesense).  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

# SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Search::Typesense

You can also look for information at:

- Github Repo

    [https://github.com/Ovid/Search-Typesense/](https://github.com/Ovid/Search-Typesense/)

- Issue Tracker

    [https://github.com/Ovid/Search-Typesense/issues](https://github.com/Ovid/Search-Typesense/issues)

- Search CPAN

    [https://metacpan.org/release/Search-Typesense](https://metacpan.org/release/Search-Typesense)

# ACKNOWLEDGEMENTS

# LICENSE AND COPYRIGHT

This software is Copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software, licensed under:

    The Artistic License 2.0 (GPL Compatible)
