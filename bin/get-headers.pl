#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Getopt::Long;

use PopularHeaders::Fetcher;
use PopularHeaders::Util qw(verbose);

my $url;
GetOptions (
    "u|url=s"   => \$url,
);

my $fetcher = PopularHeaders::Fetcher->new();

# Program can be run with just a single URL request
if ($url) {
    verbose("Fetching one-off site: $url");
    my ($code, $headers) = $fetcher->get_url_header($url);
    print Dumper($headers) . "\n";
    exit;
}

# Otherwise assuming we have a list to work through via STDIN
while(<>) {
    chomp;
    verbose("Fetching site: $_");
    my ($code, $headers) = $fetcher->get_url_header($_);
    print Dumper($headers) . "\n";
}
