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
my $batch = 50;
my $url;
GetOptions (
    "a|alexa"   => \$alexa,
    "b|batch=i" => \$batch,
    "u|url=s"   => \$url,
);


# Program can be run with just a single URL request in which case don't bother
# to make a DB object etc
if ($url) {
    verbose("Fetching one-off site: $url");
    my ($code, $headers) = $fetcher->get_url_header({
        'site' => $url
    }, $delay, \&show_results);
    $delay->wait;
    exit;
}

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
    $fetcher->get_url_header(
        $target, $delay, \&store_results
    );

    if ($i == $batch) {
        print "$k Sites Processed. Waiting for next batch...\n";
        $delay->wait;
        $i = 0;
    }
}

# Catch any queued outside of a block
$delay->wait;
verbose "Finishing...\n";


#
# Helper functions for IOLoop
#
sub store_results {
    my ($site) = @_;
    my $result = $db->add_header(@_);
    verbose("Adding " . $site->{'site'} . " => " . $result->{added});
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

How many URLs should be requested at once before blocking until they
have all either returned a result or timed-out. This value defaults
to 100.

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
