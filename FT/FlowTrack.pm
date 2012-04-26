package FT::FlowTrack;

use Carp;
use strict;
use warnings;
use autodie;
use Log::Message::Simple qw[:STD :CARP];
use DBI;



sub new
{
    my $class = shift;
    my $self = {};

    ($self->{location},$self->{debug}) = @_;

    # ensure we have some defaults
    $self->{location} ||= "/tmp";
    $self->{debug} ||= 0;

    # Setup space for connection pools and the database handle
    $self->{db_connection_pool} = {};
    $self->{dbh} = {};


    bless($self, $class);
    return $self;
}




sub _initDB
{
    my ($self, $db_name) = @_;

    my $dbfile = $self->{location} . "/" . $db_name;

    if(defined($self->{db_connection_pool}{$$})) {
	$self->{dbh} = $self->{db_connection_pool}{$$};
	return $self->{dbh};
    }  else  {
	my $dbh = DBI->connect("dbi:SQLite:dbname=$dbfile","","");
	if(defined($dbh)) {
	    $self->{dbh} = $dbh;
	    $self->{db_connection_pool}{$$} = $dbh;
	    return $dbh;
	}else{
	    croak( $DBI::errstr );
	}
    }
}


1;
__END__
=head1 FlowTrack

Routines surrounding the processing of the flowtrack data.

=head2 new

FlowTrack->new(<db name>,<db directory>,<logging 1 == on>);
