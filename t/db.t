use Test::More tests => 14;
use Data::Dumper;

# Assumes you have flow tools in /opt/local/bin or /usr/bin


my $DB_TEST_FILE = "FT_TEST.sqlite";

BEGIN 
{
    use_ok('FT::FlowTrack');
    
    unlink("/tmp/$DB_TEST_FILE");
}

#
# object Creation, using defaults
#

# Custom Values
my $ft = FT::FlowTrack->new("/foo", 1, "flowtrack.sqlite");
ok($ft->{location} eq "/foo", "custom location");
ok($ft->{debug} == 1, "custom debug setting");
ok($ft->{dbname} eq "flowtrack.sqlite", "custom DB name");

undef($ft);

# Default Values
$ft = FT::FlowTrack->new();
ok($ft->{location} eq "/tmp", "default location");
ok($ft->{debug} == 0, "default debug setting");
ok($ft->{dbname} eq "FlowTrack.sqlite", "default DB name");

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


#
# Now we try to do some testing of the actual flow collection
#
SKIP: {
    my $flowgen = -x "/opt/local/bin/flow-gen" ? "/opt/local/bin/flow-gen" : "/usr/bin/flow-gen";
    my $flowsend = -x "/opt/local/bin/flow-send" ? "/opt/local/bin/flow-send" : "/usr/bin/flow-send";
    
    skip "Couldn't find flowtools in /opt/local/bin or /usr/bin", 1 unless(-x $flowgen && -x $flowsend);

    # Make sure we are processing flows into the raw_flow table
    open(FT, "-|", "./FlowTrack.pl") or die ("couldn't run FlowTrack.pl: $!");
    system("$flowgen -n10 -V5 | $flowsend 0/127.0.0.1/2055");
    sleep(20);


    print(<FT>);
    close(FT);

    my $rows;
    my $sth = $dbh->preapre("SELECT fl_time FROM raw_flow");
    $rows = $sth->fetchall_arrayref();

    ok(scalar(@{$rows}) == 10, "Inserted 10 flows");
}


END
{
    #cleanup
    unlink("/tmp/$DB_TEST_FILE");
}

    
