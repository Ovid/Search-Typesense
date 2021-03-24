# How to Help

## Quickstart

If you have Perl v5.16.0 (or higher) and docker installed:

    git clone git@github.com:Ovid/Search-Typesense.git
    cd Search-Typesense
    cpan  Mojolicious Moo Type::Tiny Test::Most
    # or
    cpanm Mojolicious Moo Type::Tiny Test::Most
    docker run                           \
          -p 7777:8108 -v/tmp:/data      \
          typesense/typesense:0.19.0     \
          --data-dir /data --api-key=777
    prove -rl t

If you get through all of the above steps and the `prove` command output ends
with `Result: PASS`, you're good to go.

## Getting Started

You'll need to get Typesense up and running and then run the tests.

### Configuring Typesense

The tests assume Typesense is running on a non-standard port, 7777, with the
api key of 777.

If you use docker, you can get Typesense up and running with:

    docker run \
        -p 7777:8108 -v/tmp:/data \
        typesense/typesense:0.19.0 \
        --data-dir /data --api-key=777

We run tests on docker with a non-standard port to avoid any chance of
interfering with a live installation. I know the chances are low, but it's
still possible.

### Running the Tests

If you're not familiar with
[Dist::Zilla](https://metacpan.org/pod/Dist::Zilla), don't worry about it. The
tests can still be run via `prove -rl t`. You can see the `dist.ini` for the
list of dependencies, or the `Makefile.PL` from the [the CPAN
distribution](https://metacpan.org/pod/Search::Typesense).

### Start Hacking

Once that's good, you can create a new branch, via `git checkout -b
branch-name` and start hacking. When you're done, just issue a pull request.

If you're wondering what you can hack on, see the `TODO` section below.

## TODO

There are quite a few things we would like to have for this module.

### Additional Features

* [Federated / Multisearch](https://typesense.org/docs/0.19.0/api/documents.html#federated-multi-search)
* [Delete by Query](https://typesense.org/docs/0.19.0/api/documents.html#delete-by-query)
* [CSV Imports](https://typesense.org/docs/0.19.0/api/documents.html#import-a-csv-file)
* [Configuring import batch size](https://typesense.org/docs/0.19.0/api/documents.html#configure-batch-size)
* [API key management](https://typesense.org/docs/0.19.0/api/api-keys.html)
* [Curated Documents](https://typesense.org/docs/0.19.0/api/curation.html)
* [Aliases](https://typesense.org/docs/0.19.0/api/collection-alias.html)
* [Synonyms](https://typesense.org/docs/0.19.0/api/synonyms.html)
* [Cluster Operations](https://typesense.org/docs/0.19.0/api/cluster-operations.html)

### More Documentation

Many places in the docs refer you back to the official Typesense
documentation. It would be lovely if we could have more full-featured examples
in the POD.

### INI File Support

It would be nice to allow this:

    my $typesense = Search::Typesense->new( config => 'typesense.ini' );

### More Tests

In addition to the above, we love far more tests (especially covering
failures). We also rely on a test Typesense server being up and running (see
"Configuring Typesense" above). It would be nice to have a fallback strategy
if a live server isn't available, but this becomes a headache as features
sometimes change between Typesense versions.

### Version Checking

We have an internal version object. It would be nice to use that to test if
a feature can work. For example, if we add Federated/Multisearch, we should
`warn` or `croak` if someone requests this on a version less than `0.19.0`.

### Make Tests Configurable

If, for some reason, you can use the `docker` example above to get a test
instance of Typesense running, we might want to configure
`t/lib/Test/Search/Typesense.pm` to recognize environment variables to point
at a test instance of Typesense that you've already set up. However, the test
suite runs `$typesense->collections->delete_all`, so this will **destroy**
your Typesense data. This is definitely a "proceed with caution" area.
