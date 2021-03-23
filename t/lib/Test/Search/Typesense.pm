package Test::Search::Typesense;

use Moo;
use Test::More ();
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
    Test::More::BAIL_OUT(
"Typesense does not appear to be running. See the CONTRIBUTING.md document with this distribution."
    );
}

# If, for some strange reason, we've still hit an existing Typesense database,
# minimize the chance of hitting a valid collection
sub collection_name { 'XXX_this_will_be_deleted_after_testing_XXX' }

sub DEMOLISH {
    my $typesense = $_[0]->typesense;
    $typesense->delete_all_collections if $typesense;
}

1;
