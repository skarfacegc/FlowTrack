# This contains some basic IP utils
# Mainly here so we can memoize some of the IP operations
#

package FT::IP;
use warnings;
use strict;
use Net::IP;
use Memoize;

memoize('getIPObj');
memoize('IPOverlap');

# Returns an IP object for the provided IP
# tries to determine if it's a intip or a dotted quad
#  yes the check is actually crappy  (just checks for an integer or non integer)
#  but it should be ok in this context
sub getIPObj
{
    my ($ip) = @_;

    # If we get a raw integer
    if ( $ip =~ /^\d+$/ )
    {
        return Net::IP->new( join( '.', unpack( 'C4', pack( "N", $ip ) ) ) );
    }
    else
    {
        return Net::IP->new($ip);
    }
}

sub IPOverlap
{
    my ( $network, $ip ) = @_;

    my $network_obj = getIPObj($network);
    my $ip_obj      = getIPObj($ip);

    return $network_obj->overlaps($ip_obj) == $IP_B_IN_A_OVERLAP;
}

1;
