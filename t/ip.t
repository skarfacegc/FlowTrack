#!/usr/bin/env perl

use strict;
use warnings;

use Test::More tests => 13;
use Data::Dumper;
use Memoize;


BEGIN
{
    use_ok('FT::IP');
}

Memoize::unmemoize("FT::IP::getIPObj");
Memoize::unmemoize("FT::IP::IPOverlap");

# getIPObj Tests
my $quad_test = FT::IP::getIPObj('10.1.1.1');

isa_ok( $quad_test, "Net::IP", "Quad object creation" );
ok( $quad_test->intip() == 167837953, "Quad conversion" );

my $int_test = FT::IP::getIPObj(167837953);
isa_ok( $int_test, "Net::IP", "Int object creation" );
ok( $int_test->ip() eq '10.1.1.1', "Int conversion" );


# Overlap Tests
ok( FT::IP::IPOverlap( '10.0.0.0/8', '10.1.1.1' ), "10.1.1.1 is in 10.0.0.0/8" );
ok( !FT::IP::IPOverlap( '192.168.0.0/16', '10.0.0.1' ), "10.0.0.1 isn't in 192.168.0.0/16" );
ok( FT::IP::IPOverlap( '10.1.1.1', '10.1.1.1' ), "10.1.1.1 and 10.1.1.1 overlap" );

ok( FT::IP::IPOverlap( '10.0.0.0/8', 168100097 ), "168100097 is in 10.0.0.0/8" );
ok( !FT::IP::IPOverlap( '192.168.1.0/24', 168100097 ), "168100097 isn't in 192.168.1.0/24" );
ok( FT::IP::IPOverlap( 168100097, 168100097 ), "168100097 and 168100097 overlap" );


# resolve tests
is( FT::IP::Resolve('198.41.0.4'),         'a.root-servers.net', "198.41.0.4 resolves to a.root-servers.net" );
is( FT::IP::Resolve('a.root-servers.net'), '198.41.0.4',         "a.root-servers.net resolves to 198.41.0.4" );


