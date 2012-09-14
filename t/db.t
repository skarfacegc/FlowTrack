use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use autodie;

use Test::More tests => 14;
use Data::Dumper;
use FT::Schema;

use vars qw($DB_TEST_DIR);

# Assumes you have flow tools in /opt/local/bin or /usr/bin

my $DB_TEST_DIR = "/tmp";

BEGIN
{
    use_ok('FT::FlowTrack');
}

test_main();

sub test_main
{
    unlink("$DB_TEST_DIR/FlowTrack.sqlite") if ( -e "$DB_TEST_DIR/FlowTrack.sqlite" );
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
    my $ft_custom = FT::FlowTrack->new( "./blah", "192.168.1.1/24" );
    ok( $ft_custom->{location} eq "./blah", "custom location" );
    ok( $ft_custom->{internal_network} eq "192.168.1.1/24" );
    unlink("./blah/FlowTrack.sqlite");
    rmdir("./blah");

    # Default Values
    my $ft_default = FT::FlowTrack->new();
    ok( $ft_default->{location} eq "Data", "default location" );
    ok( $ft_default->{internal_network} eq "192.168.1.0/24" );

    # make sure we get back a well known table name
    my $tables = $ft_default->get_tables();
    ok( grep( /raw_flow/, @$tables ), "Schema List" );

    # Do a basic schema structure test
    my $table_def = $ft_default->get_table("raw_flow");
    ok( $table_def->[0]{name} eq "flow_id", "Schema Structure" );

    my $create_sql = $ft_default->get_create_sql("raw_flow");
    ok( $create_sql ~~ /CREATE.*fl_time.*/, "Create statement generation" );
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
    ok( grep( /raw_flow/, @table_list ), "raw_flow created" );
}

END
{
    #cleanup
}

