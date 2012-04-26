use Test::More tests => 8;

BEGIN 
{
    use_ok('FT::FlowTrack');
}

#
# object Creation, using defaults
#

# Custom Values
my $ft = FT::FlowTrack->new("/foo", 1);
ok($ft->{location} eq "/foo", "custom location");
ok($ft->{debug} == 1, "custom debug setting");

undef($ft);

# Default Values
$ft = FT::FlowTrack->new();
ok($ft->{location} eq "/tmp", "default location");
ok($ft->{debug} == 0, "default debug setting");

#
# DB Creation
#

#
my $db_creat = FT::FlowTrack->new("/tmp", 1);

my $dbh = $db_creat->_initDB("TEST.SQLITE");
ok(-e "/tmp/TEST.SQLITE", "database file exists");
is_deeply($dbh, $db_creat->{dbh}, "object db handle compare");
is_deeply($db_creat->{dbh}, $db_creat->{db_connection_pool}{$$}, "connection pool object storage");



END
{
    unlink("/tmp/TEST.SQLITE");
}

    
