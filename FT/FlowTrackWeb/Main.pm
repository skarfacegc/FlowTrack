package FT::FlowTrackWeb::Main;
use strict;
use warnings;
use Carp;

use FT::FlowTrack;
use Mojo::Base 'Mojolicious::Controller';
use POSIX;

# TODO: Need an answer for this
our $PORT             = 2055;
our $DATAGRAM_LEN     = 1548;
our $DBNAME           = 'FlowTrack.sqlite';
our $INTERNAL_NETWORK = '192.168.1.0/24';
our $DATA_DIR         = './Data';

our $FT = FT::FlowTrack->new( $DATA_DIR, 1, $DBNAME, $INTERNAL_NETWORK );

sub index
{
    my $self = shift();

    $self->render( template => 'index' );
}

sub simpleFlows
{
    my $self = shift();

    my ($timerange) = $self->param('timerange');

    $self->stash( flow_struct => $FT->getFlowsForLast($timerange) );
    $self->stash( timerange   => $timerange );

    $self->render( template => 'FlowsForLast' );
}

sub simpleFlowsJSON
{
    my $self = shift();

    my ($timerange) = $self->param('timerange');
    my $flow_struct = $FT->getFlowsForLast($timerange);

    my $ret_struct = {
                       sEcho               => 3,
                       iTotalRecords       => scalar @$flow_struct,
                       iTotalDisplayRecors => scalar @$flow_struct,
                       aaData              => [],
    };

    # Now we populate aaData
    foreach my $flow (@$flow_struct)
    {
        my ( $time, $microsecs ) = split( /\./, $flow->{fl_time} );
        my $timestamp = strftime("%r",localtime($time));
        
        my $row_struct = [
                           $timestamp, $flow->{src_ip_obj}->ip(),
                           $flow->{src_port},          $flow->{dst_ip_obj}->ip(),
                           $flow->{dst_port},          $flow->{bytes},
                           $flow->{packets}
        ];

        push( @{ $ret_struct->{aaData} }, $row_struct );
    }

    $self->render( { json => $ret_struct } );
}
1;
