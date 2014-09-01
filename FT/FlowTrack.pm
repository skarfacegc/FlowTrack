package FT::FlowTrack;

use feature ':5.10';
use Carp;
use strict;
use warnings;

use Log::Log4perl qw(get_logger);
use DBI;
use Data::Dumper;
use File::Path qw(make_path);
use Net::IP;
use Socket;    # For inet_ntoa
use DateTime;
use DateTime::TimeZone;
use vars '$AUTOLOAD';

use FT::Configuration;
use FT::Schema;
use FT::IP;

#
# Constructor
#
# Takes ("directory for db files",<debug>,"db file name")
#
# Sets defaults if needed
#
sub new
{
    my $class = shift;

    my $self = {};

    my ( $location, $internal_network ) = @_;

    $self->{dbname} = 'FlowTrack.sqlite';

    # ensure we have some defaults
    $self->{location}         = defined($location)         ? $location         : 'Data';
    $self->{internal_network} = defined($internal_network) ? $internal_network : '192.168.1.0/24';

    # Setup space for connection pools and the database handle
    $self->{db_connection_pool} = {};
    $self->{dbh}                = {};

    bless( $self, $class );

    $self->{tz_offset} = DateTime::TimeZone->new( name => 'local' )->offset_for_datetime( DateTime->now() );
    $self->{dbh} = $self->_initDB();
    $self->_createTables();

    return $self;
}

#
# Handles storing flows to the database
#
# Takes an array of flow records (similar to how Net::Flow combines things)
# But the array covers the entire time window, not just a single packet.
# Not doing anyting at the packet leve on this side.
#
sub storeFlow
{
    my ( $self, $flows ) = @_;
    my $logger      = get_logger();
    my $total_saved = 0;
    my $total_flows = 0;

    my $dbh = $self->_initDB();

    my $sql = qq {
      INSERT INTO raw_flow ( fl_time, src_ip, dst_ip, src_port, dst_port, bytes, packets, protocol ) 
      VALUES (?,?,?,?,?,?,?,?);
    };

    my $sth = $dbh->prepare($sql)
      or $logger->logconfess( "Couldn't preapre SQL: " . $dbh->errstr() );

    $total_flows = scalar( @{$flows} ) if ( defined($flows) );

    # ArrayTupleFetch is called repeatedly until it returns undef.  Shifts off flow records from flows
    # and returns an array of fields in the order expected by the sql above.  Removes the need for
    # batching logic and simplifies things quite a bit.
    $total_saved += $sth->execute_array(
        {
           ArrayTupleFetch => sub {
               my $flow_rec = shift(@$flows);

               return undef if ( !defined($flow_rec) );

               return [
                        $flow_rec->{fl_time},  $flow_rec->{src_ip}, $flow_rec->{dst_ip},  $flow_rec->{src_port},
                        $flow_rec->{dst_port}, $flow_rec->{bytes},  $flow_rec->{packets}, $flow_rec->{protocol}
               ];
             }
        }
    );

    $logger->debug( "Flows Saved: $total_saved of " . $total_flows );

    return 1;
}

#
# Gets flows for the last x minutes
#
# returns an array of flows for the last x minutes
sub getFlowsForLast
{
    my $self = shift;
    my ($duration) = @_;

    return $self->getFlowsInTimeRange( time - ( $duration * 60 ), time );
}

#
# Gets flows in the specified time range
#
# returns a list of:
# {
#   'protocol' => 6,
#   'bytes' => 208,
#   'src_port' => 62140,
#   'flow_id' => 1171324,
#   'packets' => 4,
#   'dst_port' => 443,
#   'src_ip' => 3232235786,
#   'dst_ip' => 1249764389,
#   'fl_time' => '1357418340.41598'
# };'
#
#
sub getFlowsInTimeRange
{
    my $self = shift;
    my ( $start_time, $end_time ) = @_;
    my $dbh    = $self->_initDB();
    my $logger = get_logger();
    my $ret_list;

    my $sql = 'SELECT * FROM raw_flow WHERE fl_time BETWEEN ? AND ? ORDER BY fl_time';
    my $sth = $dbh->prepare($sql);
    $sth->execute( $start_time, $end_time );

    while ( my $flow_ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $flow_ref;
    }

    return $ret_list;
}

#
# Return the list of ingress flows for the last minute
#
sub getIngressFlowsForLast
{
    my $self = shift;
    my ($duration) = @_;

    return $self->getIngressFlowsInTimeRange( time - ( $duration * 60 ), time );

}

#
# return ingress flows for the given time range
#
sub getIngressFlowsInTimeRange
{
    my $self = shift;
    my ( $start_time, $end_time ) = @_;
    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $ret_list;

    my $internal_network = Net::IP->new( $self->{internal_network} );

    my $sql = qq{
        SELECT * FROM raw_flow WHERE 
        fl_time >= ? AND fl_time <= ?
        AND
        src_ip NOT BETWEEN ? AND ?
        AND
        dst_ip BETWEEN ? AND ?
        ORDER BY fl_time
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( 'failed to prepare:' . $DBI::errstr );

    $sth->execute( $start_time, $end_time,
                   $internal_network->intip(),
                   $internal_network->last_int(),
                   $internal_network->intip(),
                   $internal_network->last_int() )
      or $logger->logconfess( "failed executing $sql:" . $DBI::errstr );

    while ( my $flow_ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $flow_ref;
    }

    return $ret_list;
}

#
# Return the list of internal flows for the last x minutes
#
sub getInternalFlowsForLast
{
    my $self = shift;
    my ($duration) = @_;

    return $self->getInternalFlowsInTimeRange( time - ( $duration * 60 ), time );

}

#
# return internal flows for the given time range
#
sub getInternalFlowsInTimeRange
{
    my $self = shift;
    my ( $start_time, $end_time ) = @_;
    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $ret_list;

    my $internal_network = Net::IP->new( $self->{internal_network} );

    my $sql = qq{
        SELECT * FROM raw_flow WHERE 
        fl_time >= ? AND fl_time <= ?
        AND
        src_ip BETWEEN ? AND ?
        AND
        dst_ip BETWEEN ? AND ?
        ORDER BY fl_time
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( 'failed to prepare:' . $DBI::errstr );

    $sth->execute( $start_time, $end_time,
                   $internal_network->intip(),
                   $internal_network->last_int(),
                   $internal_network->intip(),
                   $internal_network->last_int() )
      or $logger->logconfess( "failed executing $sql:" . $DBI::errstr );

    while ( my $flow_ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $flow_ref;
    }

    return $ret_list;
}

#
# Return the list of egress flows for the last minute
#
sub getEgressFlowsForLast
{
    my $self = shift;
    my ($duration) = @_;

    return $self->getEgressFlowsInTimeRange( time - ( $duration * 60 ), time );
}

#
# Returns a list of egress flows in the provided time range
#
sub getEgressFlowsInTimeRange
{
    my $self = shift;
    my ( $start_time, $end_time ) = @_;
    my $dbh    = $self->_initDB();
    my $logger = get_logger();
    my $ret_list;

    $logger = get_logger();

    my $internal_network = Net::IP->new( $self->{internal_network} );

    my $sql = qq{
        SELECT * FROM raw_flow WHERE 
        fl_time >= ? AND fl_time <= ?
        AND
        src_ip BETWEEN ? AND ?
        AND
        dst_ip NOT BETWEEN ? AND ?
        ORDER BY fl_time
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( 'failed to prepare:' . $DBI::errstr );

    $sth->execute( $start_time, $end_time,
                   $internal_network->intip(),
                   $internal_network->last_int(),
                   $internal_network->intip(),
                   $internal_network->last_int() )
      or $logger->logconfess( "failed executing $sql:" . $DBI::errstr );

    while ( my $flow_ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $flow_ref;
    }

    return $ret_list;
}

#
# Returns a list of flows between the specified addresses
#
sub getTalkerFlowsInTimeRange
{
    my $self = shift();
    my ( $src_ip, $dst_ip, $start_time, $end_time ) = @_;
    my $dbh    = $self->_initDB();
    my $logger = get_logger();
    my $ret_list;

    my $src_ip_obj = FT::IP::getIPObj($src_ip);
    my $dst_ip_obj = FT::IP::getIPObj($dst_ip);

    my $sql = qq{
        SELECT * FROM raw_flow WHERE
        fl_time >= ? AND fl_time <= ?
        AND
        src_ip = ? 
        AND
        dst_ip = ?
        ORDER BY fl_time
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( 'failed to prepare:' . $DBI::errstr );

    $sth->execute( $start_time, $end_time, $src_ip_obj->intip(), $dst_ip_obj->intip() )
      or $logger->logconfess( "failed executing $sql:" . $DBI::errstr );

    while ( my $flow_ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $flow_ref;
    }

    return $ret_list;

}

# Returns the ingress flows given a pair of IPs
#
# This will figure out which ip is internal or external and
# call getTalkerFlowsInTimeRange
#
sub getIngressTalkerFlowsInTimeRange
{
    my $self = shift();
    my ( $ip_a, $ip_b, $start_time, $end_time ) = @_;
    my $logger = get_logger();
    my $src_ip;
    my $dst_ip;
    my $ret_struct;

    my $ip_a_obj = FT::IP::getIPObj($ip_a);
    my $ip_b_obj = FT::IP::getIPObj($ip_b);

    my $internal_network = Net::IP->new( $self->{internal_network} );

    # If $ip_a is internal and ip_b is external
    # ingress is b as src a as dst
    if ( FT::IP::IPOverlap( $self->{internal_network}, $ip_a )
         && !FT::IP::IPOverlap( $self->{internal_network}, $ip_b ) )
    {
        $src_ip = $ip_b_obj->intip();
        $dst_ip = $ip_a_obj->intip();
    }

    # If $ip_b is internal and $ip_a is external
    # $ip_a is src and $ip_b is dst
    elsif ( FT::IP::IPOverlap( $self->{internal_network}, $ip_b )
            && !FT::IP::IPOverlap( $self->{internal_network}, $ip_a ) )
    {
        $src_ip = $ip_a_obj->intip();
        $dst_ip = $ip_b_obj->intip();
    }

    # at this point we're either all external or all internal, so no ingress
    else
    {
        return [];
    }

    return $self->getTalkerFlowsInTimeRange( $src_ip, $dst_ip, $start_time, $end_time );
}

# Returns the egress flows given a pair of IPs
#
# This will figure out which ip is internal or external and
# call getTalkerFlowsInTimeRange
#
sub getEgressTalkerFlowsInTimeRange
{
    my $self = shift();
    my ( $ip_a, $ip_b, $start_time, $end_time ) = @_;
    my $logger = get_logger();
    my $src_ip;
    my $dst_ip;
    my $ret_struct;

    my $ip_a_obj = FT::IP::getIPObj($ip_a);
    my $ip_b_obj = FT::IP::getIPObj($ip_b);

    my $internal_network = Net::IP->new( $self->{internal_network} );

    # If $ip_a is internal and ip_b is external
    # egress is a as src b as dst
    if ( FT::IP::IPOverlap( $self->{internal_network}, $ip_a )
         && !FT::IP::IPOverlap( $self->{internal_network}, $ip_b ) )
    {
        $src_ip = $ip_a_obj->intip();
        $dst_ip = $ip_b_obj->intip();

    }

    # If $ip_b is internal and $ip_a is external
    # egress is b as src a as dst
    elsif ( FT::IP::IPOverlap( $self->{internal_network}, $ip_b )
            && !FT::IP::IPOverlap( $self->{internal_network}, $ip_a ) )
    {
        $src_ip = $ip_b_obj->intip();
        $dst_ip = $ip_a_obj->intip();
    }

    # at this point we're either all external or all internal, so no ingress
    else
    {
        return [];
    }

    return $self->getTalkerFlowsInTimeRange( $src_ip, $dst_ip, $start_time, $end_time );
}

#
# Get bucketed flows
#
# Takes: Bucket size in mintues, how may minutes ago to search
#
# ie getSumBucketsForLast(2, 180) will get the last 3 hours of samples in 2 minute buckets
#
sub getSumBucketsForLast
{
    my $self = shift;
    my ( $bucket_size, $duration ) = @_;

    return $self->getSumBucketsForTimeRange( $bucket_size * 60, time - ( $duration * 60 ), time );

}

#
# Get total ingress/egress packets/bytes/flows for each $bucket_size buckets in the database
# bounded by start_time and end_time
#
# returns array of:
# {
#   'internal_flows' => 55,
#   'internal_bytes' => 30570,
#   'total_packets' => 783,
#   'total_bytes' => 93701,
#   'total_flows' => 156,
#   'egress_bytes' => 34452,
#   'egress_flows' => 64,
#   'ingress_flows' => 37,
#   'internal_packets' => 180,
#   'ingress_bytes' => 28679,
#   'egress_packets' => 360,
#   'bucket_time' => '1356273960',
#   'ingress_packets' => 243
# },
#
sub getSumBucketsForTimeRange
{
    my $self = shift;
    my ( $bucket_size, $start_time, $end_time ) = @_;

    my $ret_list;
    my $buckets_by_time;    # A hash per bucket for easy updating
    my $bucket_time;        # Store the time of the current bucket

    my $logger = get_logger();

    # Figure out what our "internal" range is
    # used to determine ingress/egress/and internal traffic
    my $internal_network = Net::IP->new( $self->{internal_network} );

    # List of fields we want in the final hash
    my $field_list = [
                       'internal_flows',   'internal_bytes', 'totaackets',     'total_bytes',
                       'total_flows',      'egress_bytes',   'egress_flows',   'ingress_flows',
                       'internal_packets', 'ingress_bytes',  'egress_packets', 'ingress_packets'
    ];

    # Initialize our bucket hash.  We need to do this so that we can accurately reflect buckets
    # that don't have flows. Because the database won't tell us about buckets that don't have
    # any flows.
    $buckets_by_time = _buildTimeBucketHash( $bucket_size, $start_time, $end_time, $field_list );

    # Load the flows, skip the IP object creation
    #
    # splitting on the internal, egress, ingress using sql as the comparison speed
    # was killing perf perl side.
    #
    my $internal_flows = $self->getInternalFlowsInTimeRange( $start_time, $end_time );
    my $ingress_flows = $self->getIngressFlowsInTimeRange( $start_time, $end_time );
    my $egress_flows = $self->getEgressFlowsInTimeRange( $start_time, $end_time );

    $buckets_by_time = _buildBuckets( $internal_flows, $bucket_size, $buckets_by_time, "internal" );
    $buckets_by_time = _buildBuckets( $ingress_flows,  $bucket_size, $buckets_by_time, "ingress" );
    $buckets_by_time = _buildBuckets( $egress_flows,   $bucket_size, $buckets_by_time, "egress" );

    # build our return list
    foreach my $bucket_record ( sort { $a <=> $b } keys %$buckets_by_time )
    {
        push @$ret_list, $buckets_by_time->{$bucket_record};
    }

    return $ret_list;
}

#
# Optionally takes a timestamp for the purge_interval
#
# returns # of rows purged.  -1 on error
#
sub purgeData
{
    my $self             = shift;
    my ($purge_interval) = @_;
    my $dbh              = $self->_initDB();
    my $logger           = get_logger();
    my $rows_deleted     = 0;

    if ( !defined($purge_interval) )
    {
        my $conf = FT::Configuration::getConf();

        $purge_interval = time - $conf->{purge_interval};

        return -1 if ( !defined($purge_interval) );
    }

    my $sql = qq{
        DELETE FROM raw_flow WHERE fl_time < ?
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( 'failed to prepare:' . $DBI::errstr );
    $rows_deleted = $sth->execute($purge_interval) or $logger->logconfess( 'Delete failed: ' . $DBI::errstr );
    $logger->debug("Purged: $rows_deleted") if ( $rows_deleted > 0 );

    return $rows_deleted;
}

# returns true if the provided IP is in the internal network
sub isInternal
{
    my $self = shift();
    my $ip   = shift();

    return FT::IP::IPOverlap( $self->{internal_network}, $ip );

}

#
# "Private" methods below.  Not stopping folks from calling these, but they're really not interesting
#

#
# gets a db handle
#
# Returns one if we already have a dbh for the current process, otherwise it connects to
# the DB, stores the handle in the object, and returns the dbh
#
# takes self
#
sub _initDB
{
    my ($self) = @_;
    my $logger = get_logger();

    my $db_name = $self->{dbname};

    if ( defined( $self->{db_connection_pool}{$$} ) )
    {
        $self->{dbh} = $self->{db_connection_pool}{$$};
        return $self->{dbh};
    }
    else
    {

        $self->_checkDirs();

        my $dbfile = $self->{location} . "/" . $db_name;

        my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", '', '' );

        if ( defined($dbh) )
        {
            $self->{dbh} = $dbh;
            $self->{db_connection_pool}{$$} = $dbh;
            return $dbh;
        }
        else
        {
            $logger->logconfess("_initDB failed: $dbfile");
        }
    }
}

#
# Creates the needed tables
#   raw_flow
#
# Right now this is very simple.  It may need to get more complicated as we do more with
# aggregation etc.  We'll see.
#
# Takes nothing
# fatal on error
#
sub _createTables
{
    my ($self) = @_;
    my $tables = [qw/raw_flow recent_talkers/];
    my $logger = get_logger();

    foreach my $table (@$tables)
    {
        $logger->debug( "Check/Create: " . $table );
        if ( !$self->_tableExists($table) )
        {
            my $dbh = $self->_initDB();
            my $sql = $self->get_create_sql($table);

            $logger->debug( Dumper($sql) );

            if ( !defined($sql) || $sql eq "" )
            {
                $logger->logconfess("Couldn't create SQL statement for $table");
            }

            my $sth = $dbh->prepare($sql);
            my $rv  = $sth->execute();

            if ( !defined($rv) )
            {
                $logger->logconfess($DBI::errstr);
            }
        }
    }

    return 1;
}

# returns 1 if the named table exists
sub _tableExists
{
    my $self = shift;
    my ($table_name) = @_;

    my $dbh = $self->_initDB();

    my @tables = $dbh->tables();

    return grep { /$table_name/ } @tables;
}

# Check to make sure the data directory exists, if not, create it.
sub _checkDirs
{
    my $self   = shift;
    my $logger = get_logger();
    my $err;

    unless ( -d $self->{location} )
    {

        # make path handles error checking
        make_path( $self->{location} );
    }

    # Make sure the directory exists
    $logger->logconfess( $self->{location} . ' strangely absent' )
      unless ( -d $self->{location} );

    return;
}

#
# Builds a hash of the appropriate number of
# time buckets between start_time and end_time in time_bucket
# intervals.
#
# Hash has fields for total bytes/flows/packets for internal, egress, ingress flows
sub _buildTimeBucketHash
{
    my ( $bucket_size, $start_time, $end_time, $field_list ) = @_;

    my $buckets_by_time;

    #what's our first bucket?
    my $bucket_time = _calcBucketTime( $start_time, $bucket_size );

    # Initalize the hash
    while ( $bucket_time < $end_time )
    {
        $buckets_by_time->{$bucket_time} = { 'bucket_time' => $bucket_time, };

        # Now add and initialize the fields in $field_list
        foreach my $field (@$field_list)
        {
            $buckets_by_time->{$bucket_time}{$field} = 0;
        }

        # On to the next bucket
        $bucket_time += $bucket_size;
    }

    return $buckets_by_time;

}

#
# Takes: time, bucket size
# Returns: time rounded down to the closest bucket aligned time.
#
sub _calcBucketTime
{
    my ( $time, $bucket_size ) = @_;

    return int( $time - ( int($time) % $bucket_size ) );
}

#
# Helper for the getSumBucket routines
#
# Add flows from $flow to $sum_struct
# summarizing flows into $bucket_size buckets
# prefix the hash key names with $name
#
#
# This lets us build a single datastructure with aligned
# buckets that contains multiple types of data (ingress/egress/etc)
#
# If $name isn't passed just use flows/bytes/packets
#
# I'm not a huge fan of using variable hashref names like this.
# I didn't hate it enough to refactor the entire chain.
#
#
sub _buildBuckets
{
    my ( $flows, $bucket_size, $sum_struct, $name ) = @_;
    my $logger = get_logger();
    my $ret_struct;

    if ( !defined($sum_struct) )
    {
        $logger->logconfess("sum_struct undefined in _buildBuckets");
    }

    if ( !defined($bucket_size) || $bucket_size <= 0 )
    {
        $logger->logconfess("Invalid bucket_size in _buildBuckets");
    }

    # append _ to the name if not already there
    $name = $name . "_" if ( $name !~ /_$/ );

    foreach my $flow (@$flows)
    {
        my $bucket = _calcBucketTime( $flow->{fl_time}, $bucket_size );

        $sum_struct->{$bucket}{ $name . "flows" }++;
        $sum_struct->{$bucket}{ $name . "bytes" }   += $flow->{bytes};
        $sum_struct->{$bucket}{ $name . "packets" } += $flow->{packets};

        # Update the global counters
        $sum_struct->{$bucket}{total_flows}++;
        $sum_struct->{$bucket}{total_bytes}   += $flow->{bytes};
        $sum_struct->{$bucket}{total_packets} += $flow->{packets};
    }

    return $sum_struct;
}

#
# So we can passthrough calls to the Schema routines
#
# Mainly to get the schema handling code out of this package.
#
sub AUTOLOAD
{

    # Need to shift off self.  Dont't think that FT::Schema is going to need it
    # but I'm not sure.  Either way, we want it off of @_;
    my $self = shift;

    given ($AUTOLOAD)
    {
        when (/get_tables/)
        {
            return FT::Schema::get_tables(@_);
        }

        when (/get_table/)
        {
            return FT::Schema::get_table(@_);
        }

        when (/get_create_sql/)
        {
            return FT::Schema::get_create_sql(@_);
        }

        # mainly to stop the autoloader from bitching
        when (/DESTROY/)
        {
            return;
        }

    }

    die "Couldn't find $AUTOLOAD";
}

1;
