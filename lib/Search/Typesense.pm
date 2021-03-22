package Search::Typesense;

use Moo;

use 5.10.0;
use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Mojo::URL;
use Mojo::Parameters;
use Carp qw(croak);

=head1 NAME

Search::Typesense - Perl interface to Typesense search engine.

=head1 SYNOPSIS

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

=head1 DESCRIPTION

This is a simple interface to the L<Typesense|https://typesense.org/> search
engine. Most methods will do one of three things:

=over 4

=item * Return results as defined in the Typesense documentation (listed per section)

=item * Return nothing if Typesense returns a 404.

=item * C<croak> if Typesense returns an error.

=back

=cut

use Search::Typesense::Types qw(
  ArrayRef
  Bool
  Enum
  HashRef
  InstanceOf
  NonEmptyStr
  Str
  compile
);

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.01';

has _ua => (
    is      => 'ro',
    isa     => InstanceOf ['Mojo::UserAgent'],
    lazy    => 1,
    builder => 1,
);

sub _build__ua {
    my $self = shift;
    my $ua   = Mojo::UserAgent->new;
    $ua->on(
        start => sub {
            my ( $ua, $tx ) = @_;
            $tx->req->headers->header( 'Content-Type' => 'application/json' );
            $tx->req->headers->header(
                'X-TYPESENSE-API-KEY' => $self->api_key );
        }
    );
    return $ua;
}

has _url_base => (
    is      => 'ro',
    isa     => InstanceOf ['Mojo::URL'],
    lazy    => 1,
    builder => 1,
);

has use_https => (
    is       => 'ro',
    isa      => Bool,
    required => 1,
    default  => 1,
);

has api_key => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has host => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

has port => (
    is       => 'ro',
    isa      => NonEmptyStr,
    required => 1,
);

sub _build__url_base {
    my $self = shift;
    my $url  = Mojo::URL->new;
    $url->scheme( $self->use_https ? 'https' : 'http' );
    $url->host( $self->host );
    $url->port( $self->port );
    return $url;
}

sub _url {
    my ( $self, $path ) = @_;
    return $self->_url_base->clone->path( '/' . join( '/' => @$path ) );
}

sub BUILD {
    my $self = shift;
    $self->assert_is_running;
}

=head1 METHODS

=head2 C<assert_is_running>

    $typesense->assert_is_running;

This does nothing if we can connect to Typesense. Otherwise, this method will
C<croak> with a message explaining the error.

=cut

sub assert_is_running {
    my $self = shift;
    $self->_GET( path => ['health'] );
}

=head2 C<get_collections>

    if ( my $collections = $typesense->get_collections ) {
        # returns all collections
    }
    if ( my $collections = $typesense->get_collections($collection_name) ) {
        # returns collection matching $collection_name, if any
    }

Response shown at L<https://typesense.org/docs/0.19.0/api/#retrieve-collection>

=cut

sub get_collections {
    my ( $self, $collection ) = @_;
    state $check = compile(Str);
    my @collection = $check->( $collection // '' );
    return $self->_GET( path => [ 'collections', @collection ] );
}

sub _GET {
    my ( $self, %arg_for ) = @_;
    my $request = $arg_for{request};

    my $url = $self->_url( $arg_for{path} );

    my @args = $request ? ( form => $request ) : ();
    my $tx   = $self->_ua->get( $url, @args );
    return $self->_check_for_failure( $tx, $arg_for{return_transaction} );
}

=head2 C<delete_collection>

    my $response = $typesense->delete_collection($collection_name);

Response shown at L<https://typesense.org/docs/0.19.0/api/#drop-collection>

=cut

sub delete_collection {
    my ( $self, $collection ) = @_;
    state $check = compile(NonEmptyStr);
    ($collection) = $check->($collection);
    return $self->_DELETE( path => [ 'collections', $collection ] );
}

sub _DELETE {
    my ( $self, %arg_for ) = @_;
    my $url = $self->_url( $arg_for{path} );
    my $tx  = $self->_ua->delete($url);
    return $self->_check_for_failure( $tx, $arg_for{return_transaction} );
}

=head2 C<create_collection>

    my $collection = $typesense->create_collection(\%definition);

Arguments and response as shown at
L<https://typesense.org/docs/0.19.0/api/#create-collection>

=cut

sub create_collection {
    my ( $self, $collection_definition ) = @_;
    state $check = compile(HashRef);
    ($collection_definition) = $check->($collection_definition);
    my $fields = $collection_definition->{fields};

    foreach my $field ( $fields->@* ) {
        if ( exists $field->{facet} ) {
            $field->{facet} =
              $field->{facet} ? Mojo::JSON->true : Mojo::JSON->false;
        }
    }

    return $self->_POST(
        path    => ['collections'],
        request => $collection_definition
    );
} ## end sub create_collection

sub _POST {
    my ( $self, %arg_for ) = @_;
    my $request = $arg_for{request};
    my $url     = $self->_url( $arg_for{path} );

    if ( my $query = $arg_for{query} ) {
        my $parameters = Mojo::Parameters->new(%$query);
        $url .= "?$parameters";
    }

    my @args = ref $request
      ? ( json => $request )    # data structures
      : $request ? $request     # raw POST content
      :            croak("POST $url not allowed without a request");

    my $tx = $self->_ua->post( $url, @args );
    return $self->_check_for_failure( $tx, $arg_for{return_transaction} );
}

=head2 C<create_document>

    my $document = $typesense->create_document($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#index-document>

=cut

sub create_document {
    my ( $self, $collection, $document ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $document ) = $check->( $collection, $document );
    return $self->_POST(
        path    => [ 'collections', $collection, 'documents' ],
        request => $document
    );
}

=head2 C<upsert_document>

    my $document = $typesense->upsert_document($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#upsert>

=cut

sub upsert_document {
    my ( $self, $collection, $document ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $document ) = $check->( $collection, $document );

    # XXX It's unclear to me how to have a request body and a query string at
    # the same time with the Mojo::UserAgent.
    return $self->_POST(
        path    => [ 'collections', $collection, 'documents' ],
        request => $document,
        query   => { action => 'upsert' },
    );
}

=head2 C<update_document>

    my $document = $typesense->update_document($collection, $document_id, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#update-document>

=cut

sub update_document {
    my ( $self, $collection, $document_id, $updates ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr, HashRef );
    ( $collection, $document_id, $updates ) =
      $check->( $collection, $document_id, $updates );
    return $self->_make_request(
        method  => 'patch',
        path    => [ 'collections', $collection, 'documents', $document_id ],
        request => $updates
    );
}

=head2 C<delete_document>

    my $document = $typesense->delete_document($collection_name, $document_id);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#delete-document>

=cut

sub delete_document {
    my ( $self, $collection, $document_id ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr );
    ( $collection, $document_id ) = $check->( $collection, $document_id );
    return $self->_DELETE(
        path => [ 'collections', $collection, 'documents', $document_id ] );
}

=head2 C<search>

    my $results = $typesense->search($collection_name, {q => 'London'});

The parameters for C<$query> are defined at
L<https://typesense.org/docs/0.19.0/api/#search-collection>, as are the results.

Unlike other methods, if we find nothing, we still return the data structure
(instead of C<undef> instead of a 404 exception).

=cut

sub search {
    my ( $self, $collection, $query ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $query ) = $check->( $collection, $query );

    unless ( exists $query->{q} ) {
        croak("Query parameter 'q' is required for searching");
    }
    unless ( exists $query->{query_by} ) {
        $query->{query_by} = 'search';
    }
    my $tx = $self->_GET(
        path    => [ 'collections', $collection, 'documents', 'search' ],
        request => $query,
        return_transaction => 1,
    ) or return;
    my $response = $tx->res->json;
    foreach my $hit ( $response->{hits}->@* ) {
        if ( exists $hit->{document}{json} ) {
            $hit->{document}{json} = decode_json( $hit->{document}{json} );
        }
    }
    return $response;
} ## end sub search

=head2 C<export_documents>

    my $export = $typesense->export_documents($collection_name);

Response as shown at L<https://typesense.org/docs/0.19.0/api/#export-documents>

(An arrayref of hashrefs)

=cut

sub export_documents {
    my ( $self, $collection ) = @_;
    state $check = compile(NonEmptyStr);
    ($collection) = $check->($collection);
    my $tx = $self->_GET(
        path => [ 'collections', $collection, 'documents', 'export' ],
        return_transaction => 1
    ) or return;    # 404
    return [ map { decode_json($_) } split /\n/ => $tx->res->body ];
}

=head2 C<import_documents>

    my $response = $typesense->import_documents(
      $collection_name,
      $action,
      \@documents,
   );

Response as shown at L<https://typesense.org/docs/0.19.0/api/#import-documents>

C<$action> must be one of C<create>, C<update>, or C<upsert>.

=cut

sub import_documents {
    my $self = shift;
    state $check = compile(
        NonEmptyStr,
        Enum [qw/create upsert update/],
        ArrayRef [HashRef],
    );
    my ( $collection, $action, $documents ) = $check->(@_);
    my $request_body = join "\n" => map { encode_json($_) } @$documents;

    my $tx = $self->_POST(
        path    => [ 'collections', $collection, 'documents', "import" ],
        request => $request_body,
        query   => { action => $action },
        return_transaction => 1,
    );
    my $response = $tx->res->json;
    if ( exists $response->{success} ) {
        $response->{success} += 0;
    }
    return $response;
}

=head2 C<purge>

    $typesense->purge;

Deletes everything from Typsense. B<Use with caution>!

=cut

sub purge {
    my ($self) = @_;
    my $collections = $self->get_collections;
    foreach my $collection (@$collections) {
        my $name = $collection->{name};
        $self->delete_collection($name);
    }
}

sub _check_for_failure {
    my ( $self, $tx, $return_transaction ) = @_;
    my $res = $tx->res;
    unless ( $res->is_success ) {

        return if ( $res->code // 0 ) == 404;
        my $message = $res->message // '';

        my $body   = $res->body;
        my $method = $tx->req->method;
        my $url    = $tx->req->url;
        croak("'$method $url' failed: $message. $body");
    }
    return $return_transaction ? $tx : $tx->res->json;
} ## end sub _check_for_failure

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid at allaroundtheworld.fr> >>

=head1 BUGS

Please report any bugs or feature requests to C<bug-search-typesense at rt.cpan.org>, or through
the web interface at L<https://rt.cpan.org/NoAuth/ReportBug.html?Queue=Search-Typesense>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.

=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Search::Typesense


You can also look for information at:

=over 4

=item * Github Repo

L<https://github.com/Ovid/Search-Typesense/>

=item * Issue Tracker

L<https://github.com/Ovid/Search-Typesense/issues>

=item * Search CPAN

L<https://metacpan.org/release/Search-Typesense>

=back

=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)

=cut

1;    # End of Search::Typesense
