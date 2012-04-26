#!/usr/bin/perl

# POC Code, getting the flow listener working.  Ultimately this won't be used, just keeping here for reference.

use strict;
use Net::Flow qw(decode);
use IO::Socket::INET;
use Data::Dumper;
use Socket;
use Net::IP;

# Some configuration
my $PORT     = 2055;
my $HOME_NET = "192.168.1.0/24";

# A few globals to hold the data we care about.
my $masterFlowData;    # Global hash for storing flowdata
my $addressTimes;      # Global has to help expire IPs

main();

sub main
{
    my $receive_port     = $PORT;
    my $packet           = undef;
    my $TemplateArrayRef = undef;
    my $sock =
      IO::Socket::INET->new( LocalPort => $receive_port, Proto => 'udp' );

    while ( $sock->recv( $packet, 1548 ) )
    {

        my ( $HeaderHashRef, $FlowArrayRef, $ErrorsArrayRef ) = ();

        ( $HeaderHashRef, $TemplateArrayRef, $FlowArrayRef, $ErrorsArrayRef ) =
          Net::Flow::decode( \$packet, $TemplateArrayRef );

        storeFlow($FlowArrayRef);
    }
}

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
sub storeFlow
{
    my $FlowArrayRef = shift();

    foreach my $flow ( @{$FlowArrayRef} )
    {
        my $src_raw  = unpack( "H*", $flow->{'8'} );
        my $dst_raw  = unpack( "H*", $flow->{'12'} );
        my $sprt_raw = unpack( "H*", $flow->{'7'} );
        my $dprt_raw = unpack( "H*", $flow->{'11'} );

        my $src = inet_ntoa( pack( "N", hex($src_raw) ) );
        my $dst = inet_ntoa( pack( "N", hex($dst_raw) ) );
        my $sprt = hex($sprt_raw);
        my $dprt = hex($dprt_raw);

        my $tmp_ip = getIP( $flow->{'8'} );
        print $src . " " . $tmp_ip->ip() . "\n";
    }
}

sub getIP
{
    my $raw_ip = shift();
    my $ip;

    $ip = new Net::IP( inet_ntoa($raw_ip) ) || die "Couldn't create net object";

    return $ip;
}
