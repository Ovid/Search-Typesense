package Search::Typesense;

use v5.16.0;

use Moo;
with 'Search::Typesense::Role::Request';

use Mojo::JSON qw(decode_json encode_json);
use Mojo::UserAgent;
use Mojo::URL;
use Carp qw(croak);

use Search::Typesense::Document ();
use Search::Typesense::Collection;
use Search::Typesense::Version;
use Search::Typesense::Types qw(
  ArrayRef
  Bool
  Enum
  HashRef
  InstanceOf
  NonEmptyStr
  PositiveInt
  compile
);

=head1 NAME

Search::Typesense - Perl interface to Typesense search engine.

=head1 SYNOPSIS

    my $typesense = Search::Typesense->new(
        host      => $host,    # required
        api_key   => $key,     # required
        port      => $port,    # defaults to 8108
        use_https => $bool,    # defaults to true
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

L<Check here for a comparison to ElasticSearch and similar technologies|https://typesense.org/typesense-vs-algolia-vs-elasticsearch-vs-meilisearch/>.

=head1 DESCRIPTION

B<ALPHA CODE>. The interface can and will change without warning.

This is an interface to the L<Typesense|https://typesense.org/> search
engine. Most methods will do one of three things:

=over 4

=item * Return results as defined in the Typesense documentation (listed per section)

=item * Return nothing if Typesense returns a 404.

=item * C<croak> if Typesense returns an error.

=back

=cut

our $VERSION = '0.07';

has collections => (
    is       => 'lazy',
    isa      => InstanceOf ['Search::Typesense::Collection'],
    init_arg => undef,
    handles  => [qw/search/],
    builder  => sub {
        my $self = shift;
        return Search::Typesense::Collection->new(
            user_agent => $self->_ua,
            url        => $self->_url_base,
        );
    },
);

has documents => (
    is       => 'lazy',
    isa      => InstanceOf ['Search::Typesense::Document'],
    init_arg => undef,
    builder  => sub {
        my $self = shift;
        return Search::Typesense::Document->new(
            user_agent => $self->_ua,
            url        => $self->_url_base,
        );
    },
);

# this sub without a body is called a "forward declaration" and it allows the
# requires() in Search::Typesense::Role::Request to realize that we really do
# provide these methods.

sub _ua;
has _ua => (
    is      => 'lazy',
    isa     => InstanceOf ['Mojo::UserAgent'],
    builder => sub {
        my $self = shift;
        my $ua   = Mojo::UserAgent->new;
        my $key  = $self->api_key;
        $ua->on(
            start => sub {
                my ( $ua, $tx ) = @_;
                $tx->req->headers->header(
                    'Content-Type' => 'application/json' )
                  ->header( 'X-TYPESENSE-API-KEY' => $key );
            }
        );
        return $ua;
    },
);

sub _url_base;
has _url_base => (
    is      => 'lazy',
    isa     => InstanceOf ['Mojo::URL'],
    builder => sub {
        my $self = shift;
        my $url  = Mojo::URL->new;
        $url->scheme( $self->use_https ? 'https' : 'http' );
        $url->host( $self->host );
        $url->port( $self->port );
        return $url;
    },
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
    is      => 'ro',
    isa     => PositiveInt,
    default => 8108,
);

sub BUILD {
    my $self = shift;
    $self->assert_is_running;
}

=head1 CONSTRUCTOR

The constructor takes a list (or hashref) of key/value pairs.

    my $typesense = Search::Typesense->new(
        host      => $host,    # required
        api_key   => $key,     # required
        port      => $port,    # defaults to 8108
        use_https => $bool,    # defaults to true
    );

=head2 C<api_key>

The api key to which will be sent as the C<X-TYPESENSE-API-KEY> header.

=head2 C<host>

The hostname to connect to.

=head2 C<port>

Optional port number to connect to. Defaults to 8108 if not supplied.

=head2 C<use_https>

Optional boolean. Whether or not to connect to Typesense over https. Default true.

=head1 METHODS

=head2 C<collections>

    my $collections = $typesense->collections;
    my $collection  = $collections->get($collection_name);
    my $results     = $collections->search($collection_name, {q => 'London'});

Returns an instance of L<Search::Typesense::Collection> for managing Typesense collections.

=head2 C<search>

    my $results = $typesense->search($collection_name, {q => 'London'});

Shorthand that delegated to C<< $typesense->collections->search(...) >>.

We provide this on the top-level C<$typesense> object because this is the
common case.

=head2 C<documents>

    my $documents = $typesense->documents;
    my $document  = $documents->delete($collection_name, $document_id);

Returns an instance of L<Search::Typesense::Document> for managing Typesense documents.

=head2 C<assert_is_running>

    $typesense->assert_is_running;

This does nothing if we can connect to Typesense. Otherwise, this method will
C<croak> with a message explaining the error.

=cut

sub assert_is_running {
    my $self = shift;
    $self->_GET( path => ['health'] );
}

=head2 C<typesense_version>

    my $version = $typesense->typesense_version;

Returns an instance of L<Search::Typesense::Version>.

If your version of Typesense is older than C<0.8.0>, this method will return
nothing.

=cut

sub typesense_version {
    my $self = shift;
    my $result = $self->_GET( path => ['debug'] ) or return;
    return Search::Typesense::Version->new( version_string => $result->{version} );
}

1;

__END__

=head1 INTERNATIONALIZATION (I18N)

Currently Typesense supports languages that use spaces as a word separator. In
the future, a new tokenizer will be added to support languages such as Chinese
or Japanese. I do not know the timeframe for this.

=head1 AUTHOR

Curtis "Ovid" Poe, C<< <ovid at allaroundtheworld.fr> >>

=head1 BUGS

Please report any bugs or feature requests to
C<https://github.com/Ovid/Search-Typesense/issues>.  I will be notified, and
then you'll automatically be notified of progress on your bug as I make
changes.

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

Thanks for Sebastian Reidel and Matt Trout for feedback.

=head1 LICENSE AND COPYRIGHT

This software is Copyright (c) 2021 by Curtis "Ovid" Poe.

This is free software, licensed under:

  The Artistic License 2.0 (GPL Compatible)
