use Test::More tests => 2;
use strict;
use HTTP::Proxy;
use HTTP::Proxy::HeaderFilter::simple;
use t::Utils;

# create the filter
my $sub = sub {
    my ( $self, $headers, $message) = @_;
    $headers->header( X_Foo => 'Bar' );
};

my $filter = HTTP::Proxy::HeaderFilter::simple->new($sub);

# create the proxy
my $proxy = HTTP::Proxy->new(
    port     => 0,
    maxchild => 0,
    maxconn  => 2,
);
$proxy->init;
$proxy->push_filter( response => $filter );
my $url = $proxy->url;

# fork the proxy
my @pids;
push @pids, fork_proxy($proxy);

# fork the HTTP server
my $server = server_start();
my $pid = fork;
die "Unable to fork web server" if not defined $pid;

if ( $pid == 0 ) {
    server_next($server) for 1 .. 2;
    exit 0;
}
push @pids, $pid;

#
# check that the correct transformation is applied
#

# for GET requests
my $ua = LWP::UserAgent->new();
$ua->proxy( http => $url );
my $response = $ua->request( HTTP::Request->new( GET => $server->url ) );
is( $response->header( "X-Foo" ), "Bar", "Proxy applied the transformation" );

# for HEAD requests
$ua = LWP::UserAgent->new();
$ua->proxy( http => $url );
my $response = $ua->request( HTTP::Request->new( HEAD => $server->url ) );
is( $response->header( "X-Foo" ), "Bar", "Proxy applied the transformation" );

# wait for kids
wait for @pids;

