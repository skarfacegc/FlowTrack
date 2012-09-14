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
my $DB_TEST_DIR = File::Temp->newdir();

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
    dbQueryTest();
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
    ok( $ft_custom->{location} eq "./blah", "custom location" );
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
    ok( $ft_default->{location} eq "Data", "default location" );
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

    $TEST_COUNT += 6;

    return;
}

sub dbQueryTest
{
    my $db_creat = FT::FlowTrack->new($DB_TEST_DIR);

    # make sure we're setting our packet time a little in the past
    # so we don't accidently travel to the future
    my $time = time - 1;

    my $sample_flows = [

        {
           fl_time  => $time + .1,
           src_ip   => 167772161,
           dst_ip   => 167837697,
           src_port => 1024,
           dst_port => 80,
           bytes    => 8192,
           packets  => 255

        },

        {
           fl_time  => $time + .2,
           src_ip   => 167772161,
           dst_ip   => 167837697,
           src_port => 1024,
           dst_port => 80,
           bytes    => 8192,
           packets  => 255

        },

        {
           fl_time  => $time + .3,
           src_ip   => 167772161,
           dst_ip   => 167837697,
           src_port => 1024,
           dst_port => 80,
           bytes    => 8192,
           packets  => 255

        },
      ];

      use Data::Dumper;

      ok( $db_creat->storeFlow($sample_flows), "Store Flow" );
      ok( scalar(@{$db_creat->getFlowsForLast(5)})==3, "flows for last");



      $TEST_COUNT += 2;
}

END
{
    #cleanup
}

