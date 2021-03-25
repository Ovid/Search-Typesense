package Test::Search::Typesense::Cached;

use Moo;
use Test::Most ();
use Mojo::File;
use Digest::MD5 qw(md5_hex);
use Mojo::UserAgent::Mockable;
use FindBin;
use Search::Typesense::Types qw(
  InstanceOf
);

extends 'Search::Typesense';

has '+_ua' => (
    is  => 'rw',
    isa => InstanceOf ['Mojo::UserAgent'],
);

sub BUILD {
    my $self = shift;
    my @tdir = ( $FindBin::Bin, '..', 't' );
    my @host = (
        $self->_make_slug( $self->host ),
        $self->_make_slug( $self->port )
    );

    my $cache = Mojo::File->new( @tdir, 'cache', 'data', @host )->make_path;
    my $checksum
      = Mojo::File->new( @tdir, 'cache', 'checksums', @host )->make_path;
    my $test_program = Mojo::File->new($0);
    $cache    = $cache->child( $test_program->basename('.t') );
    $checksum = $checksum->child( $test_program->basename('.t') );

    my $mode             = 'record';
    my $current_checksum = md5_hex( $test_program->slurp );
    if ( -e $cache && -s _ ) {

        # The cache exists and is not empty. We assume it's good (famous last
        # words)
        my $cached_checksum;
        $cached_checksum = $checksum->slurp if -e $checksum;
        if ($cached_checksum) {
            if ( $current_checksum eq $cached_checksum ) {
                $mode = 'playback';
            }
        }
    }

    my $ua  = Mojo::UserAgent::Mockable->new( mode => $mode, file => $cache );
    my $url = $self->_url( [] );

    if ( 'record' eq $mode ) {
        $checksum->spurt($current_checksum);
        Test::Most::explain(
            "\nRecording all traffic to and from $url. This will be cached in $cache.\n\n"
        );
    }
    else {
        # if we don't include this, we get tons of extra log lines spit out to
        # STDERR when running tests
        $ua->server->app->log->level('fatal');
        Test::Most::explain(
            "\nPlaying back cached traffic to and from $url from $cache.\n\n"
        );
    }

    my $key = $self->api_key;
    $ua->on(
        start => sub {
            my ( $ua, $tx ) = @_;
            $tx->req->headers->header( 'Content-Type' => 'application/json' )
              ->header( 'X-TYPESENSE-API-KEY' => $key );
        }
    );
    $self->_ua($ua);
}

sub _make_slug {
    my ( $self, $name ) = @_;
    $name = lc($name);
    $name =~ s/^\s+|\s+$//g;
    $name =~ s/\s+/_/g;
    $name =~ tr/-/_/;
    $name =~ s/__*/_/g;
    $name =~ s/\W//g;
    $name =~ tr/_/-/;
    $name =~ s/--/-/g;
    return $name;
}

1;
__END__
DELETE GET HEAD OPTIONS PATCH POST PUT
