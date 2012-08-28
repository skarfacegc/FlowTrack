#
# FT::FlowCollector
#
# Responsible for the main event loop to pull flows off of the wire.
# uses Net::Server to do the work
#

package FT::FlowCollector;
use strict;
use warnings;
use Carp qw(cluck);
use Data::Dumper;
use Net::Flow qw(decode);
use FT::PacketHandler;
use FT::FlowTrack;

# this is what actually gets us the server
use base qw(Net::Server::PreFork);


our $PORT             = 2055;
our $DATAGRAM_LEN     = 1548;
our $DBNAME           = 'FlowTrack.sqlite';
our $INTERNAL_NETWORK = '192.168.1.0/24';
our $DATA_DIR         = './Data';

our $FT = FT::FlowTrack->new( $DATA_DIR, 1, $DBNAME, $INTERNAL_NETWORK );



#
# This starts the main flow collection routine
#
sub CollectorStart
{
    FT::FlowCollector->run(
                        port         => "*:$PORT/udp",
                        log_level    => 4,
                        min_spare_servers => 3,
                        max_spare_server => 5,
                        max_servers  => 5,
                        max_requests => 5,
    );
}

#
# Everything below here are callbacks used by Net::Server
# Main loop is process_request which gets the data from the wire,
# cooks it, and saves it into the child's net::Server object.
# When the child is recycled (after handling 5 requests) we flush the
# accumulated data to the database
#

#
# Configure the datagram length
#
sub configure_hook
{
    my $self = shift();
    $self->{server}{udp_recv_len} = $DATAGRAM_LEN;
}

#
# When the child is killed dump the accumulated data to the database
#
sub child_finish_hook
{
    my $self      = shift();
    my $flow_data = $self->{data}{flow_data};

    carp "Cleanup\n";

    # carp Dumper($self->{data}{flow_data});
    $FT->storeFlow($flow_data) if ( defined($flow_data) );
    $self->{data}{flow_data} = undef;
}


#
# Cook the data and store it back into $self
#
sub process_request
{
    my $self = shift();

    my $flow_data = FT::PacketHandler::decode_packet( $self->{server}{udp_data} );

    carp "Store Count: " . scalar( @{$flow_data} );

    push( @{ $self->{data}{flow_data} }, @$flow_data );

}

1;
