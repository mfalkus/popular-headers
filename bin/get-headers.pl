#!/usr/bin/env perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Getopt::Long;
use Mojo::IOLoop;
use Readonly;
use YAML qw(LoadFile);

use PopularHeaders::CommonDB;
use PopularHeaders::Fetcher;
use PopularHeaders::Util qw(verbose);

my $fetcher = PopularHeaders::Fetcher->new();
my $delay = Mojo::IOLoop->delay;
my $alexa;
my $batch = 200;
my $retry_limit = 2;
my $url;
GetOptions (
    "a|alexa"   => \$alexa,
    "b|batch=i" => \$batch,
    "r|retry=i" => \$retry_limit,
    "u|url=s"   => \$url,
);

# Program can be run with just a single URL request in which case don't bother
# to make a DB object etc
if ($url) {
    verbose("Fetching one-off site: $url");
    $fetcher->get_url_header({
        'site' => $url
    }, $delay, \&show_results);
    $delay->wait;
    exit;
}

my @error_urls;
my $config = LoadFile('etc/config.yaml');
my $db = PopularHeaders::CommonDB->new({
    'user' => $config->{'db_user'},
    'pass' => $config->{'db_pass'},
    'host' => $config->{'db_host'},
    'name' => $config->{'db_name'},
});

my $i = 0;
my $k = 0;
verbose "Starting, running in batches of $batch...\n";
while(<>) {
    chomp;
    my $target = {};
    if ($alexa) {
        my ($rank, $site) = split(/,/, $_, 2);
        $target->{'rank'} = $rank;
        $target->{'site'} = $site;
        $target->{'source'} = 'Alexa';

    } else {
        $target->{'site'} = $_;
    }

    $i++;
    $k++;
    my $start_time = time();
    $fetcher->get_url_header(
        $target, $delay, \&store_results
    );

    if ($i == $batch) {
        my $processed = ($k - $i);
        print "$processed Sites Processed. $i Queued. Waiting...\n";
        $delay->wait;
        my $time_el = time() - $start_time;
        my $per_url = ($time_el / $i);
        printf("\t%.0fs at %.2fs per URL\n", $time_el, $per_url);
        $i = 0;
        try_error_urls();
    }
}

# Catch any queued outside of a block
$delay->wait;
try_error_urls();
verbose "Finishing...\n";


#
# Helper functions for IOLoop
#
sub try_error_urls {
    my $urls_to_retry = scalar @error_urls;
    verbose ("Retrying $urls_to_retry failed URLs ") if $urls_to_retry;

    # store_results pushes on to error_urls, so we need to copy the current
    # to avoid having a loop of repeatedly failing URLs here.
    my @current_errors = @error_urls;
    @error_urls = ();

    while (@current_errors) {
        my $target = pop @current_errors;

        if ($target->{attempts} == $retry_limit) {
            warn "WARN: " . $target->{'site'} . " has failed $retry_limit times. It won't be fetched again\n";
            next;

        } else {
            warn "Trying again for: " . $target->{'site'} . "\n";
        }

        $fetcher->get_url_header( $target, $delay, \&store_results );
    }

    $delay->wait;
}

sub store_results {
    my ($site, $code) = @_;
    if ($code) {
        my $result = $db->add_header(@_);
        verbose("Adding " . $site->{'site'} . " => " . $result->{added});
    } else {
        warn("Unable to fetch " . $site->{'site'} . ", added to error_urls\n");
        push(@error_urls, $site);
    }
}
sub show_results {
    my ($site, $code, $headers) = @_;
    print 'Fetched: ' . $site->{'site'} . "\n";
    print 'Status Code: ' . $code . "\n";
    print "Headers: " . Dumper($headers) . "\n";
}


=head1 NAME

get-headers.pl - Retrieve and store HTTP headers

=head1 SYNOPSIS

    cat 'my-list-of-sites' | bin/gather-headers

=head1 DESCRIPTION

This script will make a HEAD request to each URL passed in on STDIN,
then store the results in a database, as defined in C<etc/config.yaml>.

=head2 Arguments

=over

=item C<a|alexa>

Correctly parses the alexa file input, which is a CSV of the format
C<rank,site>. This will then store the site, rank and source in the database.

=item C<b|batch>

Integer. How many URLs should be requested at once before blocking until they
have all either returned a result or timed-out. This value defaults to 100.

=item C<r|retry>

Integer. How many attempts should be made to fetch a URL. Defaults to 2,
the initial fetch then once more if the initial fetch failed.

Note that a failure means no response. Server error codes (e.g. response
of HTTP 500) does not count as a failure.

=item C<u|url=s>

Provide a single URL to retrieve, print out the results rather than
store the information in the database.

=item C<v>

Print each URL requested along with the returned status code and whether all
the headers were successfully added to the database. A very large returned
header value could be truncated when inserted, resulting in what will be
considered as an unsuccessful insert.

=back

=head1 NOTES

The perldoc for the C<PopularHeaders/Fetcher.pm> module explains the specifics
used for fetching with regards to how redirects are handled.

=head1 AUTHOR

Martin Falkus <http://falkus.co/>

=cut
