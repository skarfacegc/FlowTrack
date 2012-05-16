package FT::FlowTrack;

use v5.10;

use Carp;
use strict;
use warnings;
use autodie;
use Log::Message::Simple qw[:STD :CARP];
use DBI;
use Data::Dumper;
use FT::Schema;



use vars '$AUTOLOAD';

#
# Constructor
#
# Takes ("directory for db files",<debug>,"db file name")
#
# Sets defaults if needed
#x
sub new
{
    my $class = shift;
    my $self  = {};

    ( $self->{location}, $self->{debug}, $self->{dbname} ) = @_;

    # ensure we have some defaults
    $self->{dbname} ||= "FlowTrack.sqlite";
    $self->{location} ||= "/tmp";
    $self->{debug}    ||= 0;

    # Setup space for connection pools and the database handle
    $self->{db_connection_pool} = {};
    $self->{dbh}                = {};
    
    bless( $self, $class );
    return $self;
}


# TODO: THis is a bit of a mess, should clean it up.
# SHoudl turn the insert stuff into a predefined array that is used for both
# creatoin and insertion.  Avoid using the column names in code like this
sub storeFlow
{
    my ($self, $flows) = @_;
    my $insert_struct;
    
    # Don't do anything if we don't have flows
    return unless(defined($flows));
    
    my $dbh = $self->_initDB();


    # TODO: turn this into an array. . . .
    my $sql = qq{ INSERT INTO raw_flow ( fl_time, src_ip, dst_ip, src_port, dst_port, bytes, packets )
                  VALUES (?,?,?,?,?,?,?) };


    my $sth = $dbh->prepare($sql) or croak("COudln't preapre SQL: " . $DBI::errstr);
    

    foreach my $flow_rec (@{$flows})
    {
        # creat a datastructure that looks like this
        # $insert_struct->{field_name1} = [ array of all values for field_name1 ]
        # $insert_struct->{field_name1} = [ array of all values for field_name2 ]
        #
        # To be used by execute array
        map
        {
            push(@{$insert_struct->{$_}}, $flow_rec->{$_});
        }
        keys %$flow_rec
    }


    my @keys = keys %$insert_struct;
    my @values = values %$insert_struct;
    my @tuple_status;
    
    $sth->execute_array({
                         ArrayTupleStatus => \@tuple_status
                        }, 
                        $insert_struct->{fl_time},
                        $insert_struct->{src_ip},
                        $insert_struct->{dst_ip},
                        $insert_struct->{src_port},
                        $insert_struct->{dst_port},
                        $insert_struct->{bytes},
                        $insert_struct->{packets}) or croak(print Dumper(\@tuple_status) . $DBI::errstr);
    
    print("Saved " . scalar @{ $flows } . " flows");
    
}

#
# gets a db handle
#
# Returns one if we already have a dbh for the current process, otherwise it connects to 
# the DB, stores the handle in the object, and returns the dbh
#
# takes self
# croaks on error
#
sub _initDB
{
    my ( $self) = @_;

    my $db_name =  $self->{dbname};

    if ( defined( $self->{db_connection_pool}{$$} ) )
    {
        $self->{dbh} = $self->{db_connection_pool}{$$};
        return $self->{dbh};
    }
    else
    {
        my $dbfile = $self->{location} . "/" . $db_name;

        my $dbh = DBI->connect( "dbi:SQLite:dbname=$dbfile", "", "" );

        if ( defined($dbh) )
        {
            $self->{dbh} = $dbh;
            $self->{db_connection_pool}{$$} = $dbh;
            return $dbh;
        }
        else
        {
        
            croak("_initDB failed: $dbfile" . $DBI::errstr);
        }
    }
}

#
# Creates the needed tables
#   raw_flow
#
# Right now this is very simple.  It may need to get more complicated as we do more with 
# aggregation etc.  We'll see.
#
# Takes nothing
# croaks on error
#
sub _createTables
{
    my ($self) = @_;
    my $tables = [qw/raw_flow/];

    foreach my $table (@$tables)
    {
        if(!$self->_tableExists($table))
        {
            my $dbh = $self->_initDB();
            my $sql = $self->get_create_sql($table);
            
            my $sth = $dbh->prepare($sql);
            my $rv = $sth->execute();
            
            if(!defined($rv))
            {
                croak($DBI::errstr);
            }
        }
    }    
    
    return 1;
}


# returns 1 if the named table exists
sub _tableExists
{
    my $self = shift();
    my ($table_name) = @_;

    my $dbh = $self->_initDB();
    
    my @tables = $dbh->tables();

    return grep {/$table_name/}  @tables;
}


#
# So we can passthrough calls to the Schema routines
#
sub AUTOLOAD
{
    # Need to shift off self.  Dont't think that FT::Schema needs it
    # but I'm not sure.  Eithe way, we want it off of @_;
    my $self = shift();

    given($AUTOLOAD)
    {
        when (/get_tables/)
        {
            return FT::Schema::get_tables(@_);
        }
        
        when(/get_table/)
        {
            return FT::Schema::get_table(@_);
        }

        when(/get_create_sql/)
        {
            return FT::Schema::get_create_sql(@_);
        }

        
    }
}
1;
__END__

=head1 FlowTrack

Routines surrounding the processing of the flowtrack data.

Only the public methods

=head2 new

FlowTrack->new(<db directory>,<logging 1 == on>, <dbname>);

FlowTrack->storeFlow($flow_list);
