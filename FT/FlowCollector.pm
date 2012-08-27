#!/usr/bin/env perl

package FlowCollector;
use strict;
use warnings;
use Data::Dumper;
use Net::Flow qw(decode);
use FT::PacketHandler;

our $PORT         = 2055;
our $DATAGRAM_LEN = 1548;

# this is what actually gets us the server
use base qw(Net::Server::PreForkSimple);

FlowCollector->run(
                    port         => "*:$PORT/udp",
                    log_level    => 4,
                    max_servers  => 5,
                    max_requests => 5,
);

sub configure_hook
{
    my $self = shift();
    $self->{server}{udp_recv_len} = $DATAGRAM_LEN;
}

sub child_finish_hook
{
    sleep 5;
}

sub process_request
{
    my $self = shift();

    #warn Dumper(FT::PacketHandler::decode_packet($self->{server}{udp_data}));
    $self->{counter}++;

    warn "$$ " . $self->{counter} . "\n";
}

1;
