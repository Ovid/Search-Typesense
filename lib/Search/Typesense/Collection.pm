package Search::Typesense::Collection;

use v5.16.0;

use Moo;
with 'Search::Typesense::Role::Request';

use Search::Typesense::Types qw(
  HashRef
  InstanceOf
  NonEmptyStr
  Str
  compile
);

sub _ua;
has _ua => (
    is       => 'lazy',
    isa      => InstanceOf ['Mojo::UserAgent'],
    weak_ref => 1,
    init_arg => 'user_agent',
    required => 1,
);

sub _url_base;
has _url_base => (
    is       => 'lazy',
    isa      => InstanceOf ['Mojo::URL'],
    weak_ref => 1,
    init_arg => 'url',
    required => 1,
);

=head1 NAME

Search::Typesense::Collection - CRUD for Typesense collections

=head1 SYNOPSIS

    my $typesense = Search::Typesense->new(
        host    => $host,
        api_key => $key,
    );
    my $collections = $typesense->collections;

The instantiation of this module is for internal use only. The methods are
public.

=head2 C<get>

    if ( my $collections = $typesense->collections->get ) {
        # returns all collections
    }
    if ( my $collections = $typesense->collections->get($collection_name) ) {
        # returns collection matching $collection_name, if any
    }

Response shown at L<https://typesense.org/docs/0.19.0/api/#retrieve-collection>

=cut

our $VERSION = '0.05';

sub get {
    my ( $self, $collection ) = @_;
    state $check = compile(Str);
    my @collection = $check->( $collection // '' );
    return $self->_GET( path => [ 'collections', @collection ] );
}

=head2 C<create>

    my $collection = $typesense->collections->create(\%definition);

Arguments and response as shown at
L<https://typesense.org/docs/0.19.0/api/#create-collection>

=cut

sub create {
    my ( $self, $collection_definition ) = @_;
    state $check = compile(HashRef);
    ($collection_definition) = $check->($collection_definition);
    my $fields = $collection_definition->{fields};

    foreach my $field (@$fields) {
        if ( exists $field->{facet} ) {
            $field->{facet} =
              $field->{facet} ? Mojo::JSON->true : Mojo::JSON->false;
        }
    }

    return $self->_POST(
        path    => ['collections'],
        request => $collection_definition
    );
}

=head2 C<delete>

    my $response = $typesense->collections->delete($collection_name);

Response shown at L<https://typesense.org/docs/0.19.0/api/#drop-collection>

=cut

sub delete {
    my ( $self, $collection ) = @_;
    state $check = compile(NonEmptyStr);
    ($collection) = $check->($collection);
    return $self->_DELETE( path => [ 'collections', $collection ] );
}

=head2 C<delete_all>

    $typesense->collections->delete_all;

Deletes everything from Typsense. B<Use with caution>!

=cut

sub delete_all {
    my ($self) = @_;
    my $collections = $self->get;
    foreach my $collection (@$collections) {
        my $name = $collection->{name};
        $self->delete($name);
    }
}

1;

