# Contains the schema definition
#
# Basically this is just arrays in the form
#
# $foo->[0] = {
#                  name => "my_field",
#                  type => "string"
#                  pk => 1,
#
#
#                  #TODO: Add index support
#                  indexes => ["myIndex1", "myIndex2"]
#
# }
#
# Also has routines to provide an API to access the above.

package FT::Schema;
use feature ':5.10';

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;

use Data::Dumper;

use vars '$TABLES';

# Holds the table definitions.  Could wrap this in a method to get rid of the global.
# Not sure it's needed here.
my $TABLES;

#
# Setup the definition for the raw_flow table
#
$TABLES->{"raw_flow"} = [

    # Key (auto inc)
    {
       name => "flow_id",
       type => "INTEGER PRIMARY KEY",
    },

    # Flow Time
    {
       name => "fl_time",
       type => "BIGINT NOT NULL",
    },

    # Source IP
    {
       name => "src_ip",
       type => "INT",
    },

    # Destination IP
    {
       name => "dst_ip",
       type => "INT",
    },

    # Source Port
    {
       name => "src_port",
       type => "INT"
    },

    # Destination Port
    {
       name => "dst_port",
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
    },

    # protocol
    {
        name => "protocol",
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

#
# Get the definition for a table
#
sub get_table
{
    my ($table) = @_;

    if ( exists( $TABLES->{$table} ) )
    {
        return $TABLES->{$table};
    }
    else
    {
        return;
    }
}

# Returns the list of fields
sub get_field_list
{
    my ($table) = @_;

    my $field_list;

    my $table_def = get_table($table);

    foreach my $field (@$field_list)
    {
        push( @$field_list, $field->{'name'} );
    }

    return $field_list;
}

#
# This routine builds the create statement for the given table name
# it uses the data structures setup above
#
sub get_create_sql
{
    my ($table_name) = @_;

    my $sql;
    my $primary_key;
    my $fields;

    my $table_def = get_table($table_name);

    # If we don't have a vaild table definition, bail
    return unless ( defined($table_def) );

    foreach my $field (@$table_def)
    {

        # build the field list
        push( @$fields, $field->{'name'} . " " . $field->{'type'} );

        # build the pk list
        push( @$primary_key, $field->{'name'} )
          if ( exists( $field->{'pk'} ) && $field->{'pk'} == 1 );
    }

    $sql = "CREATE TABLE $table_name (" . join( ',', @$fields );

    if ( defined($primary_key) )
    {
        $sql .= ", PRIMARY KEY (" . join( ',', @$primary_key ) . "))";
    }
    else
    {
        $sql .= ")";
    }

    return $sql;
}

1;