package FT::IP;
use warnings;
use strict;
use Memoize;
use Net::IP;

memoize('getIPObj');

sub getIPObj
{
    my ($ip) = @_;
    return Net::IP->new( join( '.', unpack( 'C4', pack( "N", $ip ) ) ) );
}

1;
