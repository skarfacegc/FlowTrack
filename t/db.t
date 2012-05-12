use strict;
use warnings;
use Test::More tests => 15;
use Data::Dumper;
use FT::Schema;

# Assumes you have flow tools in /opt/local/bin or /usr/bin


my $DB_TEST_FILE = "FT_TEST.sqlite";

BEGIN 
{
    use_ok('FT::FlowTrack');
}

test_main();
sub test_main
{
    object_tests();
    db_creation();
}

#
# Object Creation
# Make sure custom settings and default settings work.
# 
# Make sure the schema definition stuff passes through cleanly
#
sub object_tests
{
    #
    # object Creation, using defaults
    #

    # Custom Values
    my $ft_custom = FT::FlowTrack->new("/foo", 1, "flowtrack.sqlite");
    ok($ft_custom->{location} eq "/foo", "custom location");
    ok($ft_custom->{debug} == 1, "custom debug setting");
    ok($ft_custom->{dbname} eq "flowtrack.sqlite", "custom DB name");

    # Default Values
    my $ft_default = FT::FlowTrack->new();
    ok($ft_default->{location} eq "/tmp", "default location");
    ok($ft_default->{debug} == 0, "default debug setting");
    ok($ft_default->{dbname} eq "FlowTrack.sqlite", "default DB name");


    # make sure we get back a well known table name
    my $tables = $ft_default->get_tables();    
    ok(grep(/raw_flow/, @$tables), "Schema List");

    # Do a basic schema structure test
    my $table_def = $ft_default->get_table("raw_flow");
    ok($table_def->[0]{name} eq "fl_time", "Schema Structure");
}


#
# Check Database Creation routines
#
sub db_creation
{

    #
    # DB Creation
    #
    # We'll use $dbh and $db_creat for several areas of testing
    #

    #
    my $db_creat = FT::FlowTrack->new("/tmp", 1, $DB_TEST_FILE);

    my $dbh = $db_creat->_initDB();
    ok(-e "/tmp/$DB_TEST_FILE", "database file exists");
    is_deeply($dbh, $db_creat->{dbh}, "object db handle compare");
    is_deeply($db_creat->{dbh}, $db_creat->{db_connection_pool}{$$}, "connection pool object storage");

    #
    # Table creation
    #
    ok($db_creat->_createTables(), "Table Creation");

    ok($db_creat->_createTables(), "Table creation (re-entrant test)");

    #
    # Check to make sure tables were created
    #
    my @table_list = $dbh->tables();
    ok(grep(/raw_flow/, @table_list), "raw_flow created");
}



END
{
    #cleanup
    unlink("/tmp/$DB_TEST_FILE");
}

    
