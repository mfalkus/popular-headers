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
