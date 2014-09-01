#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use autodie;
use File::Temp;

use Test::More tests => 35;
use Data::Dumper;
use FT::Schema;
use Log::Log4perl;

BEGIN
{
    use_ok('FT::FlowTrack');
}

test_main();

sub test_main
{
    # This is here mainly to squash warnings
    my $empty_log_config = qq{log4perl.rootLogger=FATAL, Screen
                              log4perl.appender.Screen = Log::Log4perl::Appender::Screen
                              log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout};

    Log::Log4perl::init( \$empty_log_config );

    # Run the tests!
    customObjects();
    defaultObjectTests();
    dbCreation();
    dbRawQueryTests();
    dbByteBucketQueryTests();
}

#
# Object Creation
# Make sure custom settings and default settings work.
#
# Make sure the schema definition stuff passes through cleanly
#
sub customObjects
{
    #
    # object Creation, using defaults
    #

    # Custom Values
    my $ft_custom = FT::FlowTrack->new( "./blah", "192.168.1.1/24" );
    ok( $ft_custom->{location} eq "./blah",                 "custom location" );
    ok( $ft_custom->{internal_network} eq "192.168.1.1/24", "custom network" );
    unlink("./blah/FlowTrack.sqlite");
    rmdir("./blah");

}

sub defaultObjectTests
{
    # Default Values
    my $ft_default = FT::FlowTrack->new();
    ok( $ft_default->{location} eq "Data",                   "default location" );
    ok( $ft_default->{internal_network} eq "192.168.1.0/24", "default network" );

    # make sure we get back a well known table name
    my $tables = $ft_default->get_tables();
    ok( grep( {/raw_flow/} @$tables ), "Schema List" );

    # Do a basic schema structure test
    my $table_def = $ft_default->get_table("raw_flow");
    ok( $table_def->[0]{name} eq "flow_id", "Schema Structure" );

    my $create_sql = $ft_default->get_create_sql("raw_flow");
    ok( $create_sql ~~ /CREATE.*fl_time.*/, "Create statement generation" );

}

#
# Check Database Creation routines
#
sub dbCreation
{
    #
    # DB Creation
    #
    # We'll use $dbh and $db_creat for several areas of testing
    #
    my $db_location = getTmp();

    my $db_creat = FT::FlowTrack->new($db_location);

    my $dbh = $db_creat->_initDB();
    ok( -e "$db_location/FlowTrack.sqlite", "database file exists" );
    is_deeply( $dbh, $db_creat->{dbh}, "object db handle compare" );
    is_deeply( $db_creat->{dbh}, $db_creat->{db_connection_pool}{$$}, "connection pool object storage" );

    #
    # Table creation
    #
    ok( $db_creat->_createTables(), "Table Creation" );

    ok( $db_creat->_createTables(), "Table creation (re-entrant test)" );

    #
    # Check to make sure tables were created
    #
    my @table_list = $dbh->tables();
    ok( grep( {/raw_flow/} @table_list ), "raw_flow created" );

}

#
# uses dummy data provided by the build* routines below.
# the build* routines are not black boxes.  I'm making assumptions
# about size/count etc.
sub dbRawQueryTests
{
    my $db_location = getTmp();
    my $db_creat = FT::FlowTrack->new( $db_location, "10.0.0.1/32" );

    # Verify creation and retrieval
    # using canned data generated in buildRawFlows
    ok( $db_creat->storeFlow(),                                    "Store no flows" );
    ok( $db_creat->storeFlow( buildRawFlows() ),                   "Store Flow" );
    ok( scalar( @{ $db_creat->getFlowsForLast(5) } ) == 106,       "Flows for last" );
    ok( scalar( @{ $db_creat->getIngressFlowsForLast(5) } ) == 53, "IngressFlowsFlorLast" );
    ok( scalar( @{ $db_creat->getEgressFlowsForLast(5) } ) == 52,  "EgressFlowsFlorLast" );

    # We'll need the total count later (for the prune testing)
    # so capture the count
    my $pre_prune_count = scalar( @{ $db_creat->getFlowsInTimeRange( 0, time ) } );
    ok( $pre_prune_count == 106, "Get full db" );

    # Verify Fields are correct from the DB
    my $sample = $db_creat->getFlowsInTimeRange( 0, time );
    ok(
        $sample->[0]{src_ip} eq "167837698"
          && $sample->[0]{dst_ip} eq "167772169"
          && $sample->[0]{src_port} eq "1024"
          && $sample->[0]{dst_port} eq "80"
          && $sample->[0]{bytes} eq "8192"
          && $sample->[0]{packets} eq "255"
          && $sample->[0]{protocol} eq "7",
        "compare single record and default time sort"
    );

    # Load up a single talker pair.  Using the same src/dst as abve for the query.
    my $talker_pairs = $db_creat->getTalkerFlowsInTimeRange( '10.1.0.2', '10.0.0.9', 0, time );
    ok(
        $talker_pairs->[0]{src_ip} eq "167837698"
          && $talker_pairs->[0]{dst_ip} eq "167772169"
          && $talker_pairs->[0]{src_port} eq "1024"
          && $talker_pairs->[0]{dst_port} eq "80"
          && $talker_pairs->[0]{bytes} eq "8192"
          && $talker_pairs->[0]{packets} eq "255"
          && $talker_pairs->[0]{protocol} eq "7",
        "getTalkerFlowsInTimeRange"
    );

    #
    # Test talker ingress
    #

    # set packets to 111 so we know if we got the right one
    my $egress_pair = {
                        'protocol' => 7,
                        'bytes'    => 222,
                        'src_port' => 1024,
                        'flow_id'  => 107,
                        'packets'  => 111,
                        'dst_port' => 80,
                        'src_ip'   => 167772161,
                        'dst_ip'   => 3232235777,
                        'fl_time'  => 1408856362
    };

    # set packets to 222 so we know we got the right one in the test
    my $ingress_pair = {
                         'protocol' => 7,
                         'bytes'    => 222,
                         'src_port' => 1024,
                         'flow_id'  => 107,
                         'packets'  => 222,
                         'dst_port' => 80,
                         'src_ip'   => 3232235777,
                         'dst_ip'   => 167772161,
                         'fl_time'  => 1408856362
    };

    $db_creat->storeFlow( [ $egress_pair, $ingress_pair ] );

    # Ingress
    my $ingress_talker_quad = $db_creat->getIngressTalkerFlowsInTimeRange( '10.0.0.1', '192.168.1.1', 0, time );
    ok( $ingress_talker_quad->[0]{packets} == 222, "getIngressTalkerFlowsInTimeRange - pair test dotted quad fwd" );

    # Now reverse the pairs
    $ingress_talker_quad = $db_creat->getIngressTalkerFlowsInTimeRange( '192.168.1.1', '10.0.0.1', 0, time );
    ok( $ingress_talker_quad->[0]{packets} == 222, "getIngressTalkerFlowsInTimeRange - pair test dotted quad reverse" );

    my $ingress_talker_int = $db_creat->getIngressTalkerFlowsInTimeRange( 3232235777, 167772161, 0, time );
    ok( $ingress_talker_int->[0]{packets} == 222, "getIngressTalkerFlowsInTimeRange - pair test ip as int fwd" );

    # Reverse the pair
    $ingress_talker_int = $db_creat->getIngressTalkerFlowsInTimeRange( 167772161, 3232235777, 0, time );
    ok( $ingress_talker_int->[0]{packets} == 222, "getIngressTalkerFlowsInTimeRange - pair test ip as int reverse" );

    # Egress
    my $egress_talker_quad = $db_creat->getEgressTalkerFlowsInTimeRange( '10.0.0.1', '192.168.1.1', 0, time );
    ok( $egress_talker_quad->[0]{packets} == 111, "getEgressTalkerFlowsInTimeRange - pair test dotted quad fwd" );

    # reverse the pair
    $egress_talker_quad = $db_creat->getEgressTalkerFlowsInTimeRange( '192.168.1.1', '10.0.0.1', 0, time );
    ok( $egress_talker_quad->[0]{packets} == 111, "getEgressTalkerFlowsInTimeRange - pair test dotted quad reverse" );

    my $egress_talker_int = $db_creat->getEgressTalkerFlowsInTimeRange( 3232235777, 167772161, 0, time );
    ok( $egress_talker_int->[0]{packets} == 111, "getEgressTalkerFlowsInTimeRange - pair test ip as int fwd" );

    # reverse the pair
    $egress_talker_int = $db_creat->getEgressTalkerFlowsInTimeRange( 167772161, 3232235777, 0, time );
    ok( $egress_talker_int->[0]{packets} == 111, "getEgressTalkerFlowsInTimeRange - pair test ip as int reverse" );

    #
    # Test Purge
    #

    # Add a single record at the beginning of time so we have some way
    # to make sure the purge isn't overly agressive
    # use the sample record from above, set it's time to 0 and store away.
    $sample->[0]{fl_time} = 0;
    $db_creat->storeFlow( [ $sample->[0] ] );

    # now test purging
    ok( $db_creat->purgeData( time - 86400 ) == 3, "purge data" );

}

#
# Do the byte bucket tests
sub dbByteBucketQueryTests
{
    # Need a new DB Dir (so we don't fight with data from the last test)
    my $db_location = getTmp();

    my $db_creat = FT::FlowTrack->new( $db_location, "10.0.0.1/32" );
    $db_creat->storeFlow( buildFlowsForBucketTest(300) );

    my $tmp_flows = $db_creat->getSumBucketsForTimeRange( 300, time - 299702, time );

    # Now test some bucketing
    ok( scalar @{$tmp_flows} == 1000, "Buckets in time range" );

    # Make sure the sums work
    ok(
        $tmp_flows->[1]{ingress_bytes} == 12288
          && $tmp_flows->[1]{egress_bytes} == 24576
          && $tmp_flows->[1]{total_bytes} == 36864,
        "Byte Sum"
    );

    ok(
        $tmp_flows->[1]{ingress_packets} == 768
          && $tmp_flows->[1]{egress_packets} == 1536
          && $tmp_flows->[1]{total_packets} == 2304,
        "Packet Sum"
    );

    # Make sure that the relative call returns something. getting the time alignment correct
    # is likely more trouble than it's worth  so I'm looking for non-zero count.  this actully just
    # calls getSumBuckgetsForTimeRange underneath so I've already verified that the base call is
    # working correctly above.
    ok( scalar @{ $db_creat->getSumBucketsForLast( 300, 15 ) } > 0, "Buckets for last" );
}

#
# Build some sample flows
# These are for the raw selects (i.e. not trying to bucketize the results.)
#
sub buildRawFlows
{

    my $flow_list;
    my $sample_flow;

    my $time = time - 1;

    # First we add a flow at the beginning of time (to test our date math)
    my $ancient_flow = {
                         fl_time  => $time - 2,    # Add a somewhat old packet.
                         src_ip   => 167837698,    # 10.1.0.2
                         dst_ip   => 167772169,    # 10.0.0.9
                         src_port => 1024,
                         dst_port => 80,
                         bytes    => 8192,
                         packets  => 255,
                         protocol => 7
    };

    push( @$flow_list, $ancient_flow );

    # 105 is just enough to trip the batching code
    for ( my $i = 0 ; $i < 105 ; $i++ )
    {
        my $sample_to_use;
        my $sample_flow_egress = {
            fl_time => $time + ( $i * .001 ),    # Just want a small time step
            src_ip   => 167772161,               # 10.0.0.1
            dst_ip   => 167837697,               # 10.1.0.1
            src_port => 1024,
            dst_port => 80,
            bytes    => 8192,
            packets  => 255,
            protocol => 6
        };
        my $sample_flow_ingress = {
            fl_time => $time + ( $i * .001 ),    # Just want a small time step
            src_ip   => 167837697,               # 10.1.0.1
            dst_ip   => 167772161,               # 10.0.0.1
            src_port => 1024,
            dst_port => 80,
            bytes    => 8192,
            packets  => 255,
            protocol => 7
        };

        if ( $i % 2 == 0 )
        {
            $sample_flow = $sample_flow_ingress;
        }
        else
        {
            $sample_flow = $sample_flow_egress;
        }

        push( @$flow_list, $sample_flow );
    }

    return $flow_list;
}

#
# Generate some nice even buckets
#
sub buildFlowsForBucketTest
{
    my ($bucket_size) = @_;

    my $flow_list;
    my $flows_in_each_bucket = 3;       # number of both egress and ingress flows to put in each bucket
    my $total_flows          = 1000;    # Total number of both egress and ingress flows to return
    my $current_bucket       = 0;       # holds the current bucket
    my $i;

    for ( $i = 0 ; $i < $total_flows ; $i++ )
    {
        for ( my $j = 0 ; $j < $flows_in_each_bucket ; $j++ )
        {
            my $sample_flow_egress = {
                fl_time => time - ( $j + $current_bucket ),
                src_ip   => 167772161,    # 10.0.0.1
                dst_ip   => 167837697,    # 10.1.0.1
                src_port => 1024,
                dst_port => 80,
                bytes    => 8192,
                packets  => 512,
                protocol => 6
            };
            my $sample_flow_ingress = {
                fl_time => time - ( $j + $current_bucket ),
                src_ip   => 167837697,    # 10.1.0.1
                dst_ip   => 167772161,    # 10.0.0.1
                src_port => 1024,
                dst_port => 80,
                bytes    => 4096,
                packets  => 256,
                protocol => 7
            };

            push( @$flow_list, $sample_flow_egress );
            push( @$flow_list, $sample_flow_ingress );
        }

        $current_bucket += $bucket_size;

    }

    return $flow_list;
}

#
# Get a tmpdir
#
sub getTmp
{
    #
    # Get some tmp space
    #
    my $tmpspace = File::Temp->new();
    return File::Temp->newdir( 'TEST_FT_XXXXXX', CLEANUP => 1 );
}

