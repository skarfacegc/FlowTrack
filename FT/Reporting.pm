# This module handles some of the longer term statistics gathering.
# RRD Graphs, tracking common talkers, etc.  It deals with the secondary data
#
package FT::Reporting;
use strict;
use warnings;
use Carp;
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
    my $self = shift;
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

        # dst IP is the internal - Ingress
        if ( $internal_network->overlaps( $flow->{dst_ip_obj} ) == $IP_B_IN_A_OVERLAP )
        {
            $flow_index = $self->buildTrackerKey( $flow->{dst_ip_obj}, $flow->{src_ip_obj} );

            $ret_struct->{$flow_index}{internal_ip} = $flow->{dst_ip_obj};
            $ret_struct->{$flow_index}{external_ip} = $flow->{src_ip_obj};

            # Make sure we have some values if undefined
            $ret_struct->{$flow_index}{ingress_bytes}   //= 0;
            $ret_struct->{$flow_index}{ingress_packets} //= 0;
            $ret_struct->{$flow_index}{ingress_flows}   //= 0;

            # Increment bytes packets and flows
            $ret_struct->{$flow_index}{ingress_bytes}   += $flow->{bytes};
            $ret_struct->{$flow_index}{ingress_packets} += $flow->{packets};
            $ret_struct->{$flow_index}{ingress_flows}   += 1;

        }

        # src IP is the internal  - Egress  (also used if neither address is internal)
        else
        {
            $flow_index = $self->buildTrackerKey( $flow->{src_ip_obj}, $flow->{dst_ip_obj} );

            $ret_struct->{$flow_index}{internal_ip} = $flow->{src_ip_obj};
            $ret_struct->{$flow_index}{external_ip} = $flow->{dst_ip_obj};

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

# Takes two net::ip objects, returns a string in the form internal-external
#
sub buildTrackerKey
{
    my $self = shift;
    my ( $ip_a_obj, $ip_b_obj ) = @_;

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

sub getAllTrackedTalkers
{
    my $self   = shift;
    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $ret_struct;

    my $sql = qq{
        SELECT * FROM recent_talkers
    };

    my $sth = $dbh->prepare($sql) or $logger->logconfess( "Couldn't prepare:\n $sql\n" . $dbh->errstr );
    $sth->execute() or $logger->logconfess( "Couldn't execute" . $dbh->errstr );

    while ( my $talker_ref = $sth->fetchrow_hashref )
    {
        # the key for this is src_ip-dst_ip to make for quick lookup
        $ret_struct->{ $talker_ref->{internal_ip} . "-" . $talker_ref->{external_ip} } = $talker_ref;

    }

    return $ret_struct;
}

#
# This routine gets a list of tracked talkers (along with the last x minutes of bytes/packets/flows)
# grouped by the internal address  The top level node also contains counts of bytes/packets/flows for all
# of the flows for that address
#
sub getTalkerTrafficForLast
{
    my $self = shift;

    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $ret_struct;

    my $talker_sql = qq{
        SELECT * FROM recent_talkers 
        ORDER BY 
            score DESC, 
            internal_ip ASC
    };

    my $ingress_flow_sql = qq{
        SELECT 
            sum(bytes) as ingress_bytes, 
            count(*) as ingress_flows, 
            sum(packets) as ingress_packets,
        FROM raw_flow
        WHERE
            src_ip = ? AND dst_ip = ?      
    };

    my $sth = $dbh->prepare($talker_sql) or $logger->logconfess( "Couldn't prepare:\n $talker_sql" . $dbh->errstr );
    $sth->execute();

    while ( my $talker_ref = $sth->fetchrow_hashref )
    {

    }

}

#
# Updates scores and adds new talkers
# to the recent_talkers database
#
# TODO: Break this up a bit
sub updateRecentTalkers
{
    my $self   = shift;
    my $logger = get_logger();
    my $dbh    = $self->_initDB();
    my $update_list;
    my $delete_list;

    my $update_sql;
    my $delete_sql;

    # From the raw_flow database
    my $recent_flows_by_addr = $self->getRecentFlowsByAddress();

    # From the recorded talkers
    my $tracked_talkers = $self->getAllTrackedTalkers();

    # Do the up-votes
    foreach my $recent_flow ( keys %$recent_flows_by_addr )
    {
        if ( exists $tracked_talkers->{$recent_flow} )
        {
            $tracked_talkers->{$recent_flow}{score} += $SCORE_INCREMENT;
            $update_list->{$recent_flow} = $tracked_talkers->{$recent_flow};
        }
        else
        {
            $tracked_talkers->{$recent_flow}{score}       = $SCORE_INCREMENT;
            $tracked_talkers->{$recent_flow}{internal_ip} = $recent_flows_by_addr->{$recent_flow}{internal_ip}->intip();
            $tracked_talkers->{$recent_flow}{external_ip} = $recent_flows_by_addr->{$recent_flow}{external_ip}->intip();

            $update_list->{$recent_flow} = $tracked_talkers->{$recent_flow};
        }
    }

    # Do the down-votes and cleanup
    foreach my $tracked_flow ( keys %$tracked_talkers )
    {
        if ( !exists $recent_flows_by_addr->{$tracked_flow} )
        {
            # Update the score in the list of tracked talkers
            # add it do the update list
            $tracked_talkers->{$tracked_flow}{score} -= $SCORE_DECREMENT;
            $update_list->{$tracked_flow} = $tracked_talkers->{$tracked_flow};
        }

        if ( $tracked_talkers->{$tracked_flow}{score} < 0 )
        {
            push @$delete_list, $tracked_talkers->{$tracked_flow};
        }
    }

    $update_sql = qq{ 
        INSERT OR REPLACE INTO 
            recent_talkers (internal_ip, external_ip, score, last_update)
        VALUES (?,?,?,?)
    };

    my $update_sth = $dbh->prepare($update_sql) or $logger->logconfess( "Couldn't prepare: " . $dbh->errstr );

    foreach my $talker_record ( keys %$update_list )
    {

        $update_sth->execute( $tracked_talkers->{$talker_record}{internal_ip},
                              $tracked_talkers->{$talker_record}{external_ip},
                              $tracked_talkers->{$talker_record}{score}, time )
          or $logger->logconfess( "insert error: " . $dbh->errstr );
    }

    $delete_sql = qq{
        DELETE FROM 
            recent_talkers
        WHERE
            internal_ip=? AND external_ip=?
    };
    my $delete_sth = $dbh->prepare($delete_sql) or $logger->logconfess( "Couldn't prepare: " . $dbh->errstr );

    foreach my $to_delete (@$delete_list)
    {
        $delete_sth->execute( $to_delete->{internal_ip}, $to_delete->{external_ip} )
          or $logger->logconfess( "Couldn't Execute: " . $dbh->errstr );
    }

    return 1;
}

1;
