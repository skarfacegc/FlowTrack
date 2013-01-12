# This module handles some of the longer term statistics gathering.
# RRD Graphs, tracking common talkers, etc.  It deals with the secondary data
#
package FT::Reporting;
use strict;
use warnings;
use parent qw{FT::FlowTrack};
use Carp;
use Data::Dumper;
use Log::Log4perl qw{get_logger};
use Net::IP;

use FT::Configuration;
use FT::FlowTrack;
use FT::IP;

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

    $self->getFlowsByTalkerPair();

    return;
}

#
# This routine gets all of the talker pairs that we've seen in the last reporting_interval
# and returns the list of flows keyed by buildTrackerKey
#
# Each record contains:
# total bytes for the talker pair
# total packets for the talker pair
# internal address for the talker pair
# external address for the talker pair
# list of flows for the talker pair
#
sub getFlowsByTalkerPair
{
    my $self               = shift();
    my $logger             = get_logger();
    my $config             = FT::Configuration::getConf();
    my $reporting_interval = $config->{reporting_interval};
    my $ret_struct;

    my $flows = $self->getFlowsForLast( $config->{reporting_interval} );

    foreach my $flow (@$flows)
    {
        my $key = $self->buildTalkerKey( $flow->{src_ip}, $flow->{dst_ip} );

        # If the src ip is internal assume that the dst is external, this
        # might not actually be the case for internal flows
        if ( $self->isInternal( $flow->{src_ip} ) )
        {
            $ret_struct->{$key}{internal} = $flow->{src_ip};
            $ret_struct->{$key}{external} = $flow->{dst_ip};
        }
        elsif ( $self->isInternal( $flow->{dst_ip} ) )
        {
            $ret_struct->{$key}{internal} = $flow->{dst_ip};
            $ret_struct->{$key}{external} = $flow->{src_ip};
        }
        else
        {
            $logger->debug("ODD: Both src and dst were external");
            next;
        }

        # Update Total Bytes (init if not defined)
        if ( !defined( $ret_struct->{$key}{total_bytes} ) )
        {
            $ret_struct->{$key}{total_bytes} = $flow->{bytes};
        }
        else
        {
            $ret_struct->{$key}{total_bytes} += $flow->{bytes};
        }

        # Update total packets (init if not defined)
        if ( !defined( $ret_struct->{$key}{total_packets} ) )
        {
            $ret_struct->{$key}{total_packets} = $flow->{packets};
        }
        else
        {
            $ret_struct->{$key}{total_packets} += $flow->{packets};
        }

        push( @{ $ret_struct->{$key}{flows} }, $flow );
    }


    return $ret_struct;
}

#
# Takes two IP addresses (integers) and returns the string
# internal-external
#
# if both are internal returns
# lowest_internal-higest_internal
sub buildTalkerKey
{
    my $self   = shift;
    my $logger = get_logger();
    my ( $ip_a, $ip_b ) = @_;

    # IP A is internal IP B isn't
    if ( $self->isInternal($ip_a) && !$self->isInternal($ip_b) )
    {
        return $ip_a . "-" . $ip_b;
    }

    # IP B is internal IP A isn't
    elsif ( $self->isInternal($ip_b) && !$self->isInternal($ip_a) )
    {
        return $ip_b . "-" . $ip_b;
    }

    # Both A & B are internal, return with lowest ip first
    elsif ( $self->isInternal($ip_a) && $self->isInternal($ip_b) )
    {
        return $ip_a < $ip_b ? $ip_a . "-" . $ip_b : $ip_b . "-" . $ip_a;
    }

}

1;
