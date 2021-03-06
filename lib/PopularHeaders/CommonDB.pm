#
# PopularHeaders wrapper around DBI
#

package PopularHeaders::CommonDB;

use strict;
use warnings;

use DBI;
use Readonly;

Readonly my $DB_SETTINGS => {
    AutoCommit => 1,
    RaiseError => 1,
    PrintError => 0,
};

sub new {
    my ($class, $params) = @_;

    my $dbh = DBI->connect(
        "DBI:mysql:database=" . $params->{'name'} . ";host=" . $params->{'host'},
        $params->{'user'},
        $params->{'pass'},
        $DB_SETTINGS,
    );

    my $insert_site = $dbh->prepare("
        INSERT IGNORE INTO sites
        (site, source, rank)
        VALUES (?, ?, ?);
    ");
    my $insert_fetch = $dbh->prepare("
        INSERT IGNORE INTO fetches
        (site, fetch_datetime, code)
        VALUES (?, NOW(), ?);
    ");
    my $insert_header = $dbh->prepare("
        INSERT INTO headers 
            (name, value, first_added, last_seen, job_offer)
            VALUES (?, ?, NOW(), NOW(), 0)
        ON DUPLICATE KEY UPDATE
            last_seen=NOW();
    ");
    my $add_fetched_header = $dbh->prepare("
        INSERT INTO fetched_headers
        (site, fetch_datetime, header_id)
        VALUES (?, NOW(), ?);
    ");
    my $get_header_id = $dbh->prepare("
        SELECT header_id FROM headers
        WHERE name = ? AND value = ?
        LIMIT 1
    ");

    my $obj = {
        dbh                     => $dbh,
        insert_site_sth         => $insert_site,
        insert_fetch_sth        => $insert_fetch,
        insert_header_sth       => $insert_header,
        add_fetched_header_sth  => $add_fetched_header,
        get_header_id_sth       => $get_header_id,
    };
    return bless $obj, $class;
}

sub add_header {
    my ($self, $target, $code, $headers) = @_;

    my $site = $target->{'site'};
    my $source = (defined $target->{'source'})
        ? $target->{'source'} : 'Unknown';
    my $rank = (defined $target->{'rank'})
        ? $target->{'rank'} : '';
     
    $self->{'insert_site_sth'}->execute(
        $site, $source, $rank
    );

    unless ($code) {
        warn "WARN: $site has no code set, number of headers: "
            . scalar keys %{$headers} . "\n";
    }

    $self->{'insert_fetch_sth'}->execute(
        $site, $code
    );

    my $result = {'added' => 1};
    foreach my $k (sort keys $headers) {
        next if ($k =~ m/Date/i);
        next if ($k =~ m/Cookie/i);

        my $insert = $self->{'insert_header_sth'}->execute($k, $headers->{$k});
        my $hd_id;

        if (defined $insert) {
            # Grab the header_id
            $self->{'get_header_id_sth'}->execute($k, $headers->{$k});
            ($hd_id) = $self->{'get_header_id_sth'}->fetchrow_array();
            $self->{'add_fetched_header_sth'}->execute($site, $hd_id) if (defined $hd_id);
        }

        unless ($insert && $hd_id) {
            $result = {
                'added' => 0,
                'error' => "Insert failed for $k: " . $headers->{$k}
            };
        }
    } # end foreach

    return $result;
}

1;

=head1 NAME

PopularHeaders::CommonDB - DB storage for popular headers

=head1 SYNOPSIS

    use PopularHeaders::CommonDB;
    my $db = PopularHeaders::CommonDB->new({
        'user' => 'your db username',
        'pass' => 'your db password',
        'host' => 'hostname for db',
        'name' => $config->{'db_name'},
    });

    $db->add_header(
        {site, source, rank}
        $code,
        $header_hash
    );

=head1 DESCRIPTION

This module simplifies the process of adding a set of HTTP headers to the
database from the popular-headers repo. The object creates a database
handle on creation then executes the relevant queries when a new set of
headers for a site are fetched.

=head2 Methods

=over

=item C<new>

Returns a new PopularHeaders::CommonDB object

=item C<add_header>

Takes a hash containing the site (e.g. google.com), source (e.g. alexa)
and rank (e.g. 1), a string containing the status code (e.g. 200) and
a hash of the HTTP headers. These will then be added to the relevant
database tables.

C<add_header> returns a hash that always has an 'added' key set to 1
for success or 0 for failure. If set to 0 an 'error' key will also be
set with an error string.

=back

=head1 AUTHOR

Martin Falkus <http://falkus.co/>

=cut
