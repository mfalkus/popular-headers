#
# PopularHeaders wrapper around Mojo::UserAgent
#

package PopularHeaders::Fetcher;

use strict;
use warnings;

use Mojo::UserAgent;

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
    my ($self, $site) = @_;

    # Setup for the HEAD request
    my $tx = $self->{ua}->build_tx(HEAD => $site);
    $tx->req->headers->remove('accept-encoding');
    $tx->req->headers->accept('*/*');
    $tx->req->headers->user_agent('Mozilla/4.0');

    $tx = $self->{ua}->start($tx);

    # Store result code
    my $headers = {};
    my $code = -1;
    eval {
        $headers = $tx->res->content->headers->to_hash;
        $code = $tx->res->code;
    };

    return ($code, $headers);
}

1;
