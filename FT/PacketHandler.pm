#
# The routines used to process the stream coming from the netflow server lives here.
# Migrated from FlowTrack.pl
package FT::PacketHandler;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;
use Time::HiRes;

#
# Actually do the packet decode
#
#
sub decode_packet
{
    my ($datagram) = @_;
    my $TemplateArrayRef = undef;
    my ( $HeaderHashRef, $FlowArrayRef, $ErrorsArrayRef ) = ();

    ( $HeaderHashRef, $TemplateArrayRef, $FlowArrayRef, $ErrorsArrayRef ) =
      Net::Flow::decode( \$datagram, $TemplateArrayRef );

    return decode_netflow($FlowArrayRef);
}

#
# Make a usable datastructure out of the data from decode_packet
# Since we can get multiple records we're returning a list here
#
#
sub decode_netflow
{
    my ($flow_struct) = @_;

    my $ret_list = [];

    foreach my $flow ( @{$flow_struct} )
    {
        my $tmp_struct = {};

        # The indicies of the data in $flow is documented in the netflow library
        # kind of a dumb way to do this, but it's not my module
        $tmp_struct->{fl_time} = Time::HiRes::time();
        $tmp_struct->{src_ip}  = hex( unpack( "H*", $flow->{'8'} ) );
        $tmp_struct->{dst_ip}  = hex( unpack( "H*", $flow->{'12'} ) );

        $tmp_struct->{src_port} = hex( unpack( "H*", $flow->{'7'} ) );
        $tmp_struct->{dst_port} = hex( unpack( "H*", $flow->{'11'} ) );
        $tmp_struct->{bytes}    = hex( unpack( "H*", $flow->{'1'} ) );
        $tmp_struct->{packets}  = hex( unpack( "H*", $flow->{'2'} ) );

        push( @{$ret_list}, $tmp_struct );

    }

    return $ret_list;
}





1;