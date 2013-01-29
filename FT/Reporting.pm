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
our $SCORE_FLOWS = 10;

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
    $self->updateRecentTalkers();

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
#
# Single record looks like:
# '3232235877-520965706' => {
#     'flows' => [
#                  {
#                    'protocol' => 6,
#                    'bytes' => 5915,
#                    'src_port' => 58950,
#                    'flow_id' => 2938843,
#                    'packets' => 77,
#                    'dst_port' => 80,
#                    'src_ip' => 3232235877,
#                    'dst_ip' => 520965706,
#                    'fl_time' => '1358003193.06847'
#                  }
#                ],
#     'total_packets' => 77,
#     'total_bytes' => 5915,
#     'external_ip' => 520965706,
#     'internal_ip' => 3232235877
#   },
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
            $ret_struct->{$key}{internal_ip} = $flow->{src_ip};
            $ret_struct->{$key}{external_ip} = $flow->{dst_ip};
        }
        elsif ( $self->isInternal( $flow->{dst_ip} ) )
        {
            $ret_struct->{$key}{internal_ip} = $flow->{dst_ip};
            $ret_struct->{$key}{external_ip} = $flow->{src_ip};
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

#
# Updates the scoring in the recent talkers database
#
#
sub updateRecentTalkers
{
    my $self   = shift();
    my $logger = get_logger();

    my $recent_flows    = $self->getFlowsByTalkerPair();
    my $tracked_talkers = $self->getTrackedTalkers();
    my $scored_flows;
    my $update_sql;

    $update_sql = qq{
        INSERT OR REPLACE INTO 
            recent_talkers (internal_ip, external_ip, score, last_update)
        VALUES
            (?,?,?,?)
    };

    # load all of our existing talker pairs into the return struct
    # decrement the score for each of them  (we'll add to it later)
    foreach my $talker_pair ( keys %$tracked_talkers )
    {
        $scored_flows->{$talker_pair} = $tracked_talkers->{$talker_pair};
        $scored_flows->{$talker_pair}{score} = $scored_flows->{$talker_pair}{score} - $SCORE_DECREMENT;
    }

    # Now go through all of our recent flows and update ret_struct;
    foreach my $recent_pair ( keys %$recent_flows )
    {
        # setup the scored flow record
        if ( !exists( $scored_flows->{$recent_pair} ) )
        {
            $scored_flows->{$recent_pair}{internal_ip} = $recent_flows->{$recent_pair}{internal_ip};
            $scored_flows->{$recent_pair}{external_ip} = $recent_flows->{$recent_pair}{external_ip};
            $scored_flows->{$recent_pair}{score}       = 0;
        }

        # Log our flow count for this pair

        $scored_flows->{$recent_pair}{score} +=
          $SCORE_INCREMENT + ( int( ( scalar @{ $recent_flows->{$recent_pair}{flows} } ) / $SCORE_FLOWS ) );

    }

    # Now do the DB updates
    # TODO: Bulk insert the data
    my $dbh = $self->_initDB();
    my $sth = $dbh->prepare($update_sql)
      or $logger->warning( "Couldn't prepare:\n\t $update_sql\n\t" . $dbh->errstr );

    foreach my $scored_flow ( keys $scored_flows )
    {
        $sth->execute( $scored_flows->{$scored_flow}{internal_ip},
                       $scored_flows->{$scored_flow}{external_ip},
                       $scored_flows->{$scored_flow}{score}, time )
          or $logger->warning( "Couldn't execute: " . $dbh->errstr );
    }

}

#
# Loads data from the recent_talkers database
#
sub getTrackedTalkers
{
    my $self       = shift();
    my $logger     = get_logger();
    my $dbh        = $self->_initDB();
    my $ret_struct = {};

    my $sql = qq{
         SELECT * FROM recent_talkers
    };

    my $sth = $dbh->prepare($sql) or $logger->warning( "Couldn't prepare:\n $sql\n" . $dbh->errstr );
    $sth->execute() or $logger->warning( "Couldn't execute" . $dbh->errstr );

    while ( my $talker_ref = $sth->fetchrow_hashref )
    {
        $ret_struct->{ $talker_ref->{internal_ip} . "-" . $talker_ref->{external_ip} } = $talker_ref;
    }

    return $ret_struct;
}

#
# purge old data from recent_talkers
#
sub purgeRecentTalkers
{

}

1;
