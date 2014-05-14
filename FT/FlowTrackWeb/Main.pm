package FT::FlowTrackWeb::Main;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;

use FT::IP;
use FT::FlowTrack;
use Mojo::Base 'Mojolicious::Controller';
use POSIX;
use Data::Dumper;

our $PORT         = 2055;
our $DATAGRAM_LEN = 1548;

# TODO: pull this from the config file
our $INTERNAL_NETWORK = '192.168.1.0/24';
our $DATA_DIR         = './Data';

our $FT = FT::FlowTrack->new( $DATA_DIR, $INTERNAL_NETWORK );
our $REPORTING = FT::Reporting->new( { data_dir => $DATA_DIR, internal_network => $INTERNAL_NETWORK } );

sub indexPage
{
    my $self = shift;
    $self->render( template => 'index' );

    return;
}

sub simpleFlows
{
    my $self = shift;

    my ($timerange) = defined( $self->param('timerange') ) ? $self->param('timerange') : 1;

    $self->stash( flow_struct => $FT->getFlowsForLast($timerange) );
    $self->stash( timerange   => $timerange );

    $self->render( template => 'FlowsForLast' );

    return;
}

sub simpleFlowsJSON
{
    my $self   = shift;
    my $logger = get_logger();

    my ($timerange) = $self->param('timerange');
    my $flow_struct = $FT->getFlowsForLast($timerange);

    my $ret_struct = {
     sEcho               => 3,
     iTotalRecords       => defined($flow_struct) ? scalar @$flow_struct : 0,
     iTotalDisplayRecors => defined($flow_struct) ? scalar @$flow_struct : 0,
     aaData              => [],
 };

    # Don't try to construct aaData if we don't have data
    if ( defined($flow_struct) )
    {
        # Now we populate aaData
        foreach my $flow (@$flow_struct)
        {
            my ( $time, $microsecs ) = split( /\./, $flow->{fl_time} );
            my $timestamp = strftime( "%r", localtime($time) );

            my $src_ip_obj = FT::IP::getIPObj( $flow->{src_ip} );
            my $dst_ip_obj = FT::IP::getIPObj( $flow->{dst_ip} );

            my $row_struct = [
            $timestamp,        $src_ip_obj->ip(), $flow->{src_port}, $dst_ip_obj->ip(),
            $flow->{dst_port}, $flow->{protocol}, $flow->{bytes},    $flow->{packets}
            ];

            push( @{ $ret_struct->{aaData} }, $row_struct );
        }

    }

    $self->render( { json => $ret_struct } );

    return;
}

#
# JSON's up the aggregate bucket datastructure
# Used for the top level graph  (should probably adjust be be more general)
#
sub aggergateBucketJSON
{
    my $self   = shift;
    my $logger = get_logger();

    my $bucketsize = $self->param('bucketsize');
    my $flow_buckets = $FT->getSumBucketsForLast( 120, 180 );
    my $ret_struct;

    # building a datastructure keyed by the field names so we can build a
    # per field list of x,y value pairs (x is always timestamp)
    # this will be turned into the final return list prior to rendering
    my $buckets_by_field;
    my $smoothed_data;

    # build a list per
    foreach my $bucket (@$flow_buckets)
    {
        foreach my $field ( keys %$bucket )
        {
            next if ( $field eq "bucket_time" );

            if ( !exists( $buckets_by_field->{$field} ) )
            {
                my $label = $field;
                $label =~ s/_/ /g;
                $buckets_by_field->{$field}{label} = $label;
            }

            # Need to convert to milliseconds and utc
            my $timestamp = ( $bucket->{bucket_time} + $FT->{tz_offset} ) * 1000;
            push( @{ $buckets_by_field->{$field}{data} }, [ $timestamp, $bucket->{$field} ] );
        }
    }

    foreach my $field ( keys %$buckets_by_field )
    {
        # remove the first and last element from each
        shift @{ $buckets_by_field->{$field}{data} };
        pop @{ $buckets_by_field->{$field}{data} };

    }

    $self->render( { json => $buckets_by_field } );

    return;

}

sub topTalkersJSON
{
    my $self   = shift;
    my $logger = get_logger();

    my $limit = $self->param('talker_count') // 21;

    my $recent_talker_list = $REPORTING->getTopRecentTalkers($limit);
    my $cooked_talker_list;

    foreach my $recent_talker (@$recent_talker_list)
    {
        
        my $talker_struct;
        my $internal_network_obj = FT::IP::getIPObj( $recent_talker->{internal_ip} );
        my $external_network_obj = FT::IP::getIPObj( $recent_talker->{external_ip} );
        my $update_time          = strftime( "%r", localtime( $recent_talker->{last_update} ) );

        $talker_struct->{internal_ip} = $internal_network_obj->ip();
        $talker_struct->{external_ip} = $external_network_obj->ip();
        $talker_struct->{internal_ip_name} = FT::IP::Resolve($talker_struct->{internal_ip});
        $talker_struct->{external_ip_name} = FT::IP::Resolve($talker_struct->{external_ip});
        $talker_struct->{update_time} = $update_time;
        $talker_struct->{score}       = $recent_talker->{score};
        $talker_struct->{id} = $recent_talker->{internal_ip} . $recent_talker->{external_ip};

        push @$cooked_talker_list, $talker_struct;

    }

    $self->render( { json => $cooked_talker_list } );

    return;
}

sub Resolve
{
    my $self   = shift;
    my $logger = get_logger();

    $logger->debug( "DNS: " . $self->param('dns') );

    $self->render( { json => { result => FT::IP::Resolve( $self->param('dns') ) } } );
}

1;
