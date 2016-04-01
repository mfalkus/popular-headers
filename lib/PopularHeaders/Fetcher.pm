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
