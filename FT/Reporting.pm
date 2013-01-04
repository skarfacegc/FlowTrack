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

    $self->getRecentTalkers();

    return;
}

#
# This routine gets all of the talker pairs that we've seen in the last reporting_interval
# and returns the list of flows keyed by buildTrackerKey
#
sub getRecentTalkers
{
    my $self = shift();
    my $logger = get_logger();
    my $config = FT::Configuration::getConf();
    my $reporting_interval = $config->{reporting_interval};
    my $ret_struct;

    my $flows = $self->getFlowsForLast($config->{reporting_interval});

    foreach my $flow (@$flows)
    {
        my $key = $self->buildTrackerKey($flow->{src_ip}, $flow->{dst_ip});

        push(@{$ret_struct->{$key}}, $flow);
    }

    return $ret_struct;    
}



# Takes two net::ip objects, returns a string in the form internal-external
#
sub buildTrackerKey
{
    my $self = shift;
    my ( $ip_a, $ip_b ) = @_;

    my $logger = get_logger;
    my $ip_a_obj = FT::IP::getIPObj($ip_a);
    my $ip_b_obj = FT::IP::getIPObj($ip_b);

    my $internal_network = Net::IP->new( $self->{internal_network} );

    if ( $internal_network->overlaps($ip_a_obj) == $IP_B_IN_A_OVERLAP )
    {
        return $ip_a_obj->intip() . "-" . $ip_b_obj->intip();
    }
    else
    {
        return $ip_b_obj->intip() . "-" . $ip_b_obj->intip();
    }

}


1;
