package Test::Search::Typesense;

use Moo;
use Test::Most ();
use Search::Typesense;
use Search::Typesense::Types qw(
  InstanceOf
);

has typesense => (
    is      => 'ro',
    isa     => InstanceOf ['Search::Typesense'],
    builder => '_build_typesense',
);

sub _build_typesense {
    my $self      = shift;
    my $typesense = eval {
        Search::Typesense->new(
            use_https => 0,
            host      => 'localhost',
            port      => 7777,
            api_key   => 777,
        );
    };
    if ($typesense) {
        $typesense->delete_all_collections;
        return $typesense;
    }

    Test::Most::explain(<<"END");
If they don't have Typesense running, we skip the tests and give them the
information they need to get the tests running. However, if they're running a
bizarrely old version of Typesense (< 0.8.0), we don't guarantee support and
we bail out.
END
    Test::More::plan( skip_all =>
"Typesense does not appear to be running. See the CONTRIBUTING.md document with this distribution."
    );
    unless ( $typesense->typesense_version ) {
        Test::More::diag(
"https://github.com/typesense/typesense-api-spec/commit/778ad3e0d2bdf23e6ccc1b23113ae6f48ec345fb"
        );
        Test::More::BAIL_OUT(
            "You're using a version of Typesense earlier than 0.8.0.");
    }
}

# If, for some strange reason, we've still hit an existing Typesense database,
# minimize the chance of hitting a valid collection
sub collection_name { 'XXX_this_will_be_deleted_after_testing_XXX' }

sub DEMOLISH {
    my $typesense = $_[0]->typesense;
    $typesense->delete_all_collections if $typesense;
}

1;
