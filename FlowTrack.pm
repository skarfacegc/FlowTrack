package FlowTrack;

use Log::Message::Simple qw[:STD :CARP];



sub new
{
    my $class = shift;
    my ($name,$path,$debug) = @_;
    
    my $self = {};
    

    # Setup space for connection pools and the database handle
    $self->{db_connection_pool} = {};
    $self->{dbh} = {};
    
    # Default to FlowTrack.db
    $self->{name} ||= 'FlowTrack.db';
    
    # Directory to store the database files
    $self->{location} ||= "q/tmp";

    $self->{debug} ||= 0;
    
    msg("DB setup", $self->{debug});

    bless($self, $class);
    return $self;
}





1;
__END__
=head1 FlowTrack

Routines surrounding the processing of the flowtrack data.

=head2 new

FlowTrack->new(<db name>,<db directory>,<logging 1 == on>);
