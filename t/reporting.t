#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use autodie;
use File::Temp;
use File::Basename;

use Test::More;
use Data::Dumper;
use Log::Log4perl;

# Holds test count
my $TEST_COUNT;

BEGIN
{
    use_ok('FT::Reporting');
    $TEST_COUNT++;
}

test_main();

sub test_main
{
    # This is here mainly to squash warnings
    my $empty_log_config = qq{log4perl.rootLogger=INFO, Screen
                              log4perl.appender.Screen = Log::Log4perl::Appender::Screen
                              log4perl.appender.Screen.layout = Log::Log4perl::Layout::SimpleLayout};
    Log::Log4perl::init( \$empty_log_config );

    # Run the tests!
    object_tests();
    db_tests();
    done_testing($TEST_COUNT);

    return;
}

sub object_tests
{
    my $reporting = FT::Reporting->new( { data_dir => scalar getTmp() } );

    ok( ref($reporting) eq 'FT::Reporting', "Object Type" );
    ok( defined $reporting->{dbh}, "parent DB handle creation" );

    $TEST_COUNT += 2;
}

sub db_tests
{
    my $reporting = FT::Reporting->new( { data_dir => scalar getTmp() } );
    my $recent_flows;

    $reporting->storeFlow( buildRawFlows() );

    $recent_flows = $reporting->getMostRecentTalkers(5);

    ok( ( $recent_flows->[0]{total_flows} + $recent_flows->[1]{total_flows} == 105 ), 'Recent flows count' );

    $TEST_COUNT += 1;
}

sub report_tests
{
    my $reporting = FT::Reporting->new( { data_dir => scalar getTmp() } );

    ok( $reporting->runReports(), "Run Reports" );

    $TEST_COUNT += 1;
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
