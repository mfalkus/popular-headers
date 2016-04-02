#
# PopularHeaders wrapper around Mojo::UserAgent
#

package PopularHeaders::Fetcher;

use strict;
use warnings;

use Mojo::UserAgent;
use Mojo::IOLoop;
use Data::Dumper;

sub new {
    my ($class) = @_;
    my $ua = Mojo::UserAgent->new;
    $ua->connect_timeout(3);
    $ua->inactivity_timeout(10);
    $ua->request_timeout(3);
    $ua->max_redirects(3);

    my $params = { ua => $ua };
    return bless $params, $class;
}

sub get_url_header {
    my ($self, $target, $delay, $db_cb) = @_;

    # Setup for the HEAD request
    my $tx = $self->{ua}->build_tx(HEAD => $target->{'site'});
    $tx->req->headers->remove('accept-encoding');
    $tx->req->headers->accept('*/*');
    $tx->req->headers->user_agent('Mozilla/4.0');

    my $cb = $delay->begin(0);
    $self->{ua}->start($tx => sub {
        my ($ua, $tx) = @_;
        my $headers = $tx->res->content->headers->to_hash;
        my $code = $tx->res->code;
        $db_cb->($target, $code, $headers) if ($db_cb);
        $cb->();
    });
}

1;

=head1 NAME

PopularHeaders::Fetcher - Non-blocking HEAD request to provided site

=head1 SYNOPSIS

    use PopularHeaders::Fetcher;
    my $fetcher = PopularHeaders::Fetcher->new();

    $fetcher->get_url_header({
        'site'      => $url
        'source'    => 'Alexa',
        'rank'      => 1000
    }, $delay, \&store_results_callback);

=head1 DESCRIPTION


=head2 Methods

=over

=item C<new>

Returns a new PopularHeaders::Fetcher object which can then be used to make
non-blocking HEAD requests.

The maximum amount of redirects that will be automatically followed is 3.
The default timeouts are:

    connect_timeout     => 3 seconds
    inactivity_timeout  => 10 seconds
    request_timeout     => 3 seconds

=item C<get_url_header>

Perform a non-blocking HEAD request to the given site.  The supplied hash must
provide at least a 'site' value to be fetched. The second argument is the
Mojo::IOLoop Delay instance, and the last value is the callback to be used
once the request has returned.

The callback is passed 3 arguments. The first is the supplied target hash, the
second is the final HTTP status code, and the last is a hash of the headers
received.

=back

=head1 AUTHOR

Martin Falkus <http://falkus.co/>

=cut
