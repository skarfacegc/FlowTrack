#
# FT::FlowCollector
#
# Responsible for the main event loop to pull flows off of the wire.
# uses Net::Server to do the work
#

package FT::FlowCollector;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;

use Data::Dumper;

use Net::Flow qw(decode);
use FT::PacketHandler;
use FT::FlowTrack;
use FT::Configuration;

# this is what actually gets us the server
use base qw(Net::Server::PreFork);

# Datagram length should be pretty consistant.
my $DATAGRAM_LEN = 1548;

# Used so we don't reload this thing repeatedly.  Actually loaded in the child_finish_hook
# only want to load it once though
my $FT;

#
# This starts the main flow collection routine
#
sub CollectorStart
{
    my $config = FT::Configuration::getConf();
    FT::FlowCollector->run(
                            port              => '*:' . $config->{netflow_port} . '/udp',
                            log_level         => 0,
                            min_spare_servers => 3,
                            max_spare_server  => 5,
                            max_servers       => 5,
                            max_requests      => 5,
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
    my $self = shift;
    $self->{server}{udp_recv_len} = $DATAGRAM_LEN;
}

#
# When the child is killed dump the accumulated data to the database
#
sub child_finish_hook
{
    my $self      = shift;
    my $flow_data = $self->{data}{flow_data};
    my $logger = get_logger();

    # Load the FT object if we need to
    if(!defined $FT)
    {
        my $config = FT::Configuration::getConf();
        $FT = FT::FlowTrack->new( $config->{data_dir}, $config->{internal_network} );
    }
    
    $logger->debug("Collector Cleanup");

    # carp Dumper($self->{data}{flow_data});
    $FT->storeFlow($flow_data) if ( defined($flow_data) );
    $self->{data}{flow_data} = undef;

    # Check to see if anything needs to be purged
    $FT->purgeData();
}

#
# Cook the data and store it back into $self
#
sub process_request
{
    my $self = shift;
    my $logger = get_logger();

    my $flow_data = FT::PacketHandler::decode_packet( $self->{server}{udp_data} );

    $logger->debug("Store Count: " . scalar( @{$flow_data} ));

    push( @{ $self->{data}{flow_data} }, @$flow_data );

}

1;
