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

        # What the fields are
        # { 'Length'=>4,'Id'=>8  }, # SRC_ADDR
        # { 'Length'=>4,'Id'=>12 }, # DST_ADDR
        # { 'Length'=>4,'Id'=>15 }, # NEXT-HOP
        # { 'Length'=>2,'Id'=>10 }, # INPUT
        # { 'Length'=>2,'Id'=>14 }, # OUTPUT
        # { 'Length'=>4,'Id'=>2  }, # PKTS
        # { 'Length'=>4,'Id'=>1  }, # BYTES
        # { 'Length'=>4,'Id'=>22 }, # FIRST
        # { 'Length'=>4,'Id'=>21 }, # LAST
        # { 'Length'=>2,'Id'=>7  }, # SRC_PORT
        # { 'Length'=>2,'Id'=>11 }, # DST_PORT
        # { 'Length'=>1,'Id'=>0  }, # PADDING
        # { 'Length'=>1,'Id'=>6  }, # FLAGS
        # { 'Length'=>1,'Id'=>4  }, # PROT
        # { 'Length'=>1,'Id'=>5  }, # TOS
        # { 'Length'=>2,'Id'=>16 }, # SRC_AS
        # { 'Length'=>2,'Id'=>17 }, # DST_AS
        # { 'Length'=>1,'Id'=>9  }, # SRC_MASK
        # { 'Length'=>1,'Id'=>13 }, # DST_MASK
        # { 'Length'=>2,'Id'=>0  }  # PADDING

        # The indicies of the data in $flow is documented in the netflow library
        # kind of a dumb way to do this, but it's not my module
        $tmp_struct->{fl_time} = Time::HiRes::time();
        $tmp_struct->{src_ip}  = hex( unpack( "H*", $flow->{8} ) );
        $tmp_struct->{dst_ip}  = hex( unpack( "H*", $flow->{12} ) );
        $tmp_struct->{src_port} = hex( unpack( "H*", $flow->{7} ) );
        $tmp_struct->{dst_port} = hex( unpack( "H*", $flow->{11} ) );
        $tmp_struct->{bytes}    = hex( unpack( "H*", $flow->{1} ) );
        $tmp_struct->{packets}  = hex( unpack( "H*", $flow->{2} ) );
        $tmp_struct->{proto}    = hex( unpack( "H*", $flow->{4} ) );
        push( @{$ret_list}, $tmp_struct );

    }

    return $ret_list;
}

1;
