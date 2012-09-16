#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use autodie;
use File::Temp;

use Test::More;
use Data::Dumper;
use FT::Schema;

use vars qw($TEST_COUNT $DB_TEST_DIR);

#
# Get some tmp space
#
my $tmpspace = File::Temp->new();
my $DB_TEST_DIR = File::Temp->newdir( 'TESTFTXXXXXX', CLEANUP => 1 );

# Holds test count
my $TEST_COUNT;

BEGIN
{
    use_ok('FT::FlowTrack');
    $TEST_COUNT += 1;
}

test_main();

sub test_main
{
    unlink("$DB_TEST_DIR/FlowTrack.sqlite") if ( -e "$DB_TEST_DIR/FlowTrack.sqlite" );
    customObjects();
    defaultObjectTests();
    dbCreation();
    dbRawQueryTests();
    dbByteBucketQueryTests();
    done_testing($TEST_COUNT);

    return;
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
    ok( $ft_custom->{location}         eq "./blah",         "custom location" );
    ok( $ft_custom->{internal_network} eq "192.168.1.1/24", "custom network" );
    unlink("./blah/FlowTrack.sqlite");
    rmdir("./blah");

    $TEST_COUNT += 2;

    return;
}

sub defaultObjectTests
{
    # Default Values
    my $ft_default = FT::FlowTrack->new();
    ok( $ft_default->{location}         eq "Data",           "default location" );
    ok( $ft_default->{internal_network} eq "192.168.1.0/24", "default network" );

    # make sure we get back a well known table name
    my $tables = $ft_default->get_tables();
    ok( grep( {/raw_flow/} @$tables ), "Schema List" );

    # Do a basic schema structure test
    my $table_def = $ft_default->get_table("raw_flow");
    ok( $table_def->[0]{name} eq "flow_id", "Schema Structure" );

    my $create_sql = $ft_default->get_create_sql("raw_flow");
    ok( $create_sql ~~ /CREATE.*fl_time.*/, "Create statement generation" );

    $TEST_COUNT += 5;

    return;
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

    my $db_creat = FT::FlowTrack->new($DB_TEST_DIR);

    my $dbh = $db_creat->_initDB();
    ok( -e "$DB_TEST_DIR/FlowTrack.sqlite", "database file exists" );
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

    # Make sure we get back the number of buckets we were expecting  (should be 1000)

    $TEST_COUNT += 6;

    return;
}

#
# uses dummy data provided by the build* routines below.
# the build* routines are not black boxes.  I'm making assumptions
# about size/count etc.
sub dbRawQueryTests
{
    $DB_TEST_DIR = File::Temp->newdir( 'TEST_RAW_XXXXXX', CLEANUP => 1 );
    my $db_creat = FT::FlowTrack->new( $DB_TEST_DIR, "10.0.0.1/32" );

    # Verify creation and retrieval
    # using canned data generated in buildRawFlows
    ok( !$db_creat->storeFlow(),                                   "Store no flows" );
    ok( $db_creat->storeFlow( buildRawFlows() ),                   "Store Flow" );
    ok( scalar( @{ $db_creat->getFlowsForLast(5) } ) == 105,       "Flows for last" );
    ok( scalar( @{ $db_creat->getIngressFlowsForLast(5) } ) == 53, "IngressFlowsFlorLast" );
    ok( scalar( @{ $db_creat->getEgressFlowsForLast(5) } ) == 52,  "EgressFlowsFlorLast" );

    # We'll need the total count later (for the prune testing)
    # so capture the count
    my $pre_prune_count = scalar( @{ $db_creat->getFlowsInTimeRange( 0, time ) } );
    ok( $pre_prune_count == 106, "Get full db" );

    # Verify Fields are correct from the DB
    my $sample = $db_creat->getFlowsInTimeRange( 0, time );
    ok(
        $sample->[0]{src_ip}        eq "167837698"
          && $sample->[0]{dst_ip}   eq "167772169"
          && $sample->[0]{src_port} eq "1024"
          && $sample->[0]{dst_port} eq "80"
          && $sample->[0]{bytes}    eq "8192"
          && $sample->[0]{packets}  eq "255"
          && $sample->[0]{protocol} eq "7",
        ,
        "compare single record and default time sort"
    );

    # now test purging
    ok( $db_creat->purgeData( time - 86400 ) == 1, "purge data" );

    $TEST_COUNT += 8;

}

#
# Do the byte bucket tests
sub dbByteBucketQueryTests
{
    # Need a new DB Dir (so we don't fight with data from the last test)
    $DB_TEST_DIR = File::Temp->newdir( 'TEST_BUCKET_XXXXXX', CLEANUP => 1 );

    my $db_creat = FT::FlowTrack->new( $DB_TEST_DIR, "10.0.0.1/32" );
    $db_creat->storeFlow( buildFlowsForBucketTest(300) );

    # Now test some bucketing
    ok( scalar @{$db_creat->getSumBucketsForTimeRange( 300, 0, time )} == 1000, "Buckets in time range" );

    # Make sure that the relative call returns something getting the time alignment correct
    # is a bit tricky, so I'm looking for non-zero count.  this actully just calls getSumBuckgetsForTimeRange
    # underneath so I've already verified that the base call is working correctly above.
    ok (scalar @{$db_creat->getSumBucketsForLast(300, 15)} > 0, "Buckets for last");

    $TEST_COUNT += 2;

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
                         fl_time  => 0,            # The dark ages
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
                packets  => 255,
                protocol => 6
            };
            my $sample_flow_ingress = {
                fl_time => time - ( $j + $current_bucket ),
                src_ip   => 167837697,    # 10.1.0.1
                dst_ip   => 167772161,    # 10.0.0.1
                src_port => 1024,
                dst_port => 80,
                bytes    => 8192,
                packets  => 255,
                protocol => 7
            };

            push( @$flow_list, $sample_flow_egress );
            push( @$flow_list, $sample_flow_ingress );
        }

        $current_bucket += $bucket_size;
    }

    return $flow_list;
}

END
{
    #cleanup
}

