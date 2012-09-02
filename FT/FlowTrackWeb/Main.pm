package FT::FlowTrackWeb::Main;
use strict;
use warnings;
use Carp;

use FT::FlowTrack;
use Mojo::Base 'Mojolicious::Controller';


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


    $self->stash(flow_struct => $FT->getFlowsForLast($timerange));
    $self->stash(timerange => $timerange);

    $self->render( template=>'FlowsForLast');
}
1;
