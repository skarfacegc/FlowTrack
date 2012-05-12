# Contains the schema definition
#
# Basically this is just arrays in the form
# 
# $foo->[0] = {
#                  name => "my_field",
#                  type => "string"
#                  pk => 1,
#                  indexes => ["myIndex1", "myIndex2"]
#                 
# }
#
# Also has routines to provide an API to access the above.


package FT::Schema;
use strict;
use warnings;
use Data::Dumper;

use vars '$TABLES';
# Holds the table definitions.  Could wrap this in a method to get rid of the global.
# Not sure it's needed here.  
my $TABLES;

#
# Setup the definition for the raw_flow table
#
$TABLES->{"raw_flow"}= 
[
 # Flow Time
 {
  name => "fl_time",
  type => "BIGINT NOT NULL",
  pk => 1, 
 },

 # Source IP
 {
  name => "src_ip",
  type => "INT",
  pk => 1,
 },

 # Destination IP
 {
  name => "dst_ip",
  type => "INT",
  pk => 1
 },

 # Source Port
 {
  name => "src_prt",
  type => "INT"
 },

 # Destination Port
 {
  name => "dst_prt",
  type => "INT"
 },

 # Traffic in bytes
 {
  name => "bytes",
  type => "INT"
 },

 # Packtes in the flow
 {
  name => "packets",
  type => "INT"
 }
];


#
# Return the list of tables
# 
sub get_tables
{
    my @table_list = keys(%$TABLES);
    return \@table_list;
}


sub get_table
{
    my ($table) = @_;

    if(exists($TABLES->{$table}))
    {
        return $TABLES->{$table};
    }
    else
    {
        return;
    }
}
