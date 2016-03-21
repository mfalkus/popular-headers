#!/usr/bin/perl

use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin/../lib";

use Data::Dumper;
use Getopt::Long;
use YAML qw(LoadFile);

use PopularHeaders::CommonDB;
use PopularHeaders::Fetcher;
use PopularHeaders::Util qw(verbose);

my $url;
GetOptions (
    "u|url=s"   => \$url,
);

my $config = LoadFile('etc/config.yaml');
my $fetcher = PopularHeaders::Fetcher->new();
my $db = PopularHeaders::CommonDB->new({
    'user' => $config->{'db_user'},
    'pass' => $config->{'db_pass'},
    'host' => $config->{'db_host'},
    'name' => $config->{'db_name'},
});

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
    my $stored = $db->add_header($_, $code, $headers);

    print STDERR "Error adding $_\n" unless ($stored->{'added'});
}
