#!/usr/bin/perl
use strict ;
use warnings;
use IO::Socket::INET;
use Net::Flow qw(decode) ;
use Data::Dumper;
use POE;
use autodie;

# Some configuration
my $PORT = 2055;
my $DATAGRAM_LEN = 1548;


POE::Session->create 
(
 inline_states => {
     _start => \&server_start,
     get_datagram => \&server_read,
 }
);
POE::Kernel->run();
exit 0;


sub server_start
{
    my $kernel = $_[KERNEL];
    my $socket = IO::Socket::INET->new(
	Proto => 'udp',
	LocalPort => $PORT
    );


    print "Starting up bizatch....\n";
    $kernel->select_read($socket, "get_datagram");
    
}



sub server_read
{
    my ($kernel, $socket) = @_[KERNEL, ARG0];
    my $packet = undef;
    my $TemplateArrayRef = undef;
    my ($HeaderHashRef, $FlowArrayRef, $ErrorsArrayRef) = ();

    my $remote_address = $socket->recv($packet, $DATAGRAM_LEN);

    my($peer_port, $peer_addr) = unpack_sockaddr_in($remote_address);
    my $human_remote = inet_ntoa($peer_addr);
    
    print "msg from: $human_remote ($peer_port)\n";
    
     ( $HeaderHashRef,
       $TemplateArrayRef,
       $FlowArrayRef,
       $ErrorsArrayRef)
	 = Net::Flow::decode(
	 \$packet,
	 $TemplateArrayRef
	 ) ;

    print Dumper($FlowArrayRef);
}




