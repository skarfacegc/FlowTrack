# This module handles some of the longer term statistics gathering.
# RRD Graphs, tracking common talkers, etc.  It deals with the secondary data
#
package FT::Reporting;
use strict;
use warnings;
use Log::Log4perl qw{get_logger};
use FT::Configuration;
use FT::FlowTrack;
use Net::IP;
use parent qw{FT::FlowTrack};
use Data::Dumper;

#
# Tune scoring
#

# How much to increment the score when we see a talker pair
our $SCORE_INCREMENT = 3;

# How much to decrement the score when we don't see a talker pair
our $SCORE_DECREMENT = 1;

# This is used to add a bit more weight to pairs with a bunch of flows
# SCORE += int(total_flows/$SCORE_FLOWS)
our $SCORE_FLOWS = 1000;

#
# All new really does here is create an FT object, and initialize the configuration
sub new
{
    my $class = shift;
    my ($config) = @_;

    return $class->SUPER::new( $config->{data_dir}, $config->{internal_network} );

}

sub runReports
{
    my $self   = shift;
    my $logger = get_logger();

    $self->updateRecentTalkers();

    return;
}

#
# This one is a little complicated, it's the key for much of the
# reporting.  We need to track two things to get the internal vs external network
# aspect of this system.  First, we need to know what the connections actually were
# grouped by the talker pair.  Second, we need some way to quickly group all of the flows
# between an internal and an external address as relative to the internal space.  For example:
#
# IH = internal host
# EH = external host
#
# Imagine the following set of flows
#
# IH -> EH  5 bytes
# EH -> IH  10 bytes
# EH -> IH  10 bytes
# IH -> EH  5 bytes
#
# We want to get the following back
# src_ip = IH
# dst_ip = EH
# total_flows = 4
# ingress_flows = 2
# egress_flows = 2
# ingress_bytes = 20
# egress_bytes = 10
# total_bytes = 30
# same for packets
# .
# .
#
# For each unique pair of talkers during the last x minutes.
#
# Doing the work perl side rather than SQL side.  May change to
# more SQL if I need to.
sub getRecentFlowsByAddress
{
    my $self = shift();
    my ($reporting_interval) = @_;

    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $raw_flows;
    my $ret_struct;
    my $net_obj_cache;

    my $internal_network = Net::IP->new( $self->{internal_network} );

    # Try to get a default time range, if we can't
    # default to 5 minutes
    if ( !defined $reporting_interval )
    {
        my $config = FT::Configuration::getConf();
        $reporting_interval = $config->{reporting_interval};

        if ( !defined $reporting_interval )
        {
            $reporting_interval = 5;
        }
    }
    $raw_flows = $self->getFlowsForLast($reporting_interval);

    foreach my $flow (@$raw_flows)
    {

        # Is the src or dst the local address.  If both are inside, then just
        # use the source address
        my $local_addr_key;

        # A composition of src and dst ip in the form:
        #  internal_network_ip-external_network_ip
        my $flow_index;

        # src IP is the internal  - Egress
        if ( $internal_network->overlaps( $flow->{src_ip_obj} ) == $IP_B_IN_A_OVERLAP )
        {
            $flow_index = $flow->{src_ip_obj}->intip() . "-" . $flow->{dst_ip_obj}->intip();

            # Make sure we have some values if undefined
            $ret_struct->{$flow_index}{egress_bytes}   //= 0;
            $ret_struct->{$flow_index}{egress_packets} //= 0;
            $ret_struct->{$flow_index}{egress_flows}   //= 0;

            # Increment bytes packets and flows
            $ret_struct->{$flow_index}{egress_bytes}   += $flow->{bytes};
            $ret_struct->{$flow_index}{egress_packets} += $flow->{packets};
            $ret_struct->{$flow_index}{egress_flows}   += 1;

        }

        # dst IP is the internal - Ingress
        elsif ( $internal_network->overlaps( $flow->{dst_ip_obj} ) == $IP_B_IN_A_OVERLAP )
        {
            $flow_index = $flow->{dst_ip_obj}->intip() . "-" . $flow->{src_ip_obj}->intip();

            # Make sure we have some values if undefined
            $ret_struct->{$flow_index}{ingress_bytes}   //= 0;
            $ret_struct->{$flow_index}{ingress_packets} //= 0;
            $ret_struct->{$flow_index}{ingress_flows}   //= 0;

            # Increment bytes packets and flows
            $ret_struct->{$flow_index}{ingress_bytes}   += $flow->{bytes};
            $ret_struct->{$flow_index}{ingress_packets} += $flow->{packets};
            $ret_struct->{$flow_index}{ingress_flows}   += 1;

        }

        # just assume src for everything that doesn't match the above.  worth an info message
        else
        {
            $logger->info("neither src or dst is in internal_network");

            $flow_index = $flow->{src_ip_obj}->intip() . "-" . $flow->{dst_ip_obj}->intip();

            # Make sure we have some values if undefined
            $ret_struct->{$flow_index}{egress_bytes}   //= 0;
            $ret_struct->{$flow_index}{egress_packets} //= 0;
            $ret_struct->{$flow_index}{egress_flows}   //= 0;

            # Increment bytes packets and flows
            $ret_struct->{$flow_index}{egress_bytes}   += $flow->{bytes};
            $ret_struct->{$flow_index}{egress_packets} += $flow->{packets};
            $ret_struct->{$flow_index}{egress_flows}   += 1;

        }
    }

    return $ret_struct;
}

sub getAllTrackedTalkers
{
    my $self   = shift();
    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $ret_struct;

    my $sql = qq{
        SELECT * FROM recent_talkers
    };

    my $sth = $dbh->prepare($sql) or $logger->warning( "Couldn't prepare:\n $sql\n" . $dbh->errstr );
    $sth->execute() or $logger->warning( "Couldn't execute" . $dbh->errstr );

    while ( my $talker_ref = $sth->fetchrow_hashref )
    {
        # the key for this is src_ip-dst_ip to make for quick lookup
        $ret_struct->{ $talker_ref->{src_ip} . "-" . $talker_ref->{dst_ip} } = $talker_ref;
    }

    return $ret_struct;
}

#
# Updates scores and adds new talkers
# to the recent_talkers database
#
sub updateRecentTalkers
{
    my $self   = shift();
    my $logger = get_logger();
    my $insert_list;

    # From the raw_flow database
    my $recent_flows_by_addr = $self->getRecentFlowsByAddress();

    # From the recorded talkers
    my $tracked_talkers = $self->getAllTrackedTalkers();

    #    warn Dumper( $recent_flows_by_addr, $tracked_talkers );
}

1;
