package Search::Typesense::Document;

use v5.16.0;

use Moo;
with 'Search::Typesense::Role::Request';

use Mojo::JSON qw(decode_json encode_json);
use Search::Typesense::Types qw(
  ArrayRef
  Enum
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

Search::Typesense::Document - CRUD for Typesense documents

=head1 SYNOPSIS

    my $typesense = Search::Typesense->new(
        host    => $host,
        api_key => $key,
    );
    my $documents = $typesense->documents;

The instantiation of this module is for internal use only. The methods are
public.

=cut

our $VERSION = '0.05';

=head2 C<create>

    my $document = $typesense->documents->create($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#index-document>

=cut

sub create {
    my ( $self, $collection, $document ) = @_;
    state $check = compile( NonEmptyStr, HashRef );
    ( $collection, $document ) = $check->( $collection, $document );
    return $self->_POST(
        path    => [ 'collections', $collection, 'documents' ],
        request => $document
    );
}

=head2 C<upsert>

    my $document = $typesense->documents->upsert($collection, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#upsert>

=cut

sub upsert {
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

=head2 C<update>

    my $document = $typesense->documents->update($collection, $document_id, \%data);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#update-document>

=cut

sub update {
    my ( $self, $collection, $document_id, $updates ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr, HashRef );
    ( $collection, $document_id, $updates ) =
      $check->( $collection, $document_id, $updates );
    return $self->_PATCH(
        path    => [ 'collections', $collection, 'documents', $document_id ],
        request => $updates
    );
}

=head2 C<delete>

    my $document = $typesense->documents->delete($collection_name, $document_id);

Arguments and response as shown at L<https://typesense.org/docs/0.19.0/api/#delete-document>

=cut

sub delete {
    my ( $self, $collection, $document_id ) = @_;
    state $check = compile( NonEmptyStr, NonEmptyStr );
    ( $collection, $document_id ) = $check->( $collection, $document_id );
    return $self->_DELETE(
        path => [ 'collections', $collection, 'documents', $document_id ] );
}

=head2 C<export>

    my $export = $typesense->documents->export($collection_name);

Response as shown at L<https://typesense.org/docs/0.19.0/api/#export-documents>

(An arrayref of hashrefs)

=cut

sub export {
    my ( $self, $collection ) = @_;
    state $check = compile(NonEmptyStr);
    ($collection) = $check->($collection);
    my $tx = $self->_GET(
        path => [ 'collections', $collection, 'documents', 'export' ],
        return_transaction => 1
    ) or return;    # 404
    return [ map { decode_json($_) } split /\n/ => $tx->res->body ];
}

=head2 C<import>

    my $response = $typesense->documents->import(
      $collection_name,
      $action,
      \@documents,
   );

Response as shown at L<https://typesense.org/docs/0.19.0/api/#import-documents>

C<$action> must be one of C<create>, C<update>, or C<upsert>.

=cut

sub import {
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

1;

