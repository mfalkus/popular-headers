#
# PopularHeader Util
#

package PopularHeaders::Util;

use strict;
use warnings;

use Exporter 'import';
our @EXPORT_OK = qw(verbose);

use Getopt::Long qw(:config pass_through);

my $verbose;
GetOptions (
    "v" => \$verbose,
);

sub verbose {
    return unless $verbose;
    print STDERR $0 . ": " . shift . "\n";
}
