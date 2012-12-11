#!/usr/bin/env perl

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;

use FT::FlowTrack;
use Data::Dumper;

my $ft = FT::FlowTrack->new( "./Data", 1, "FlowTrack.sqlite", "192.168.1.0/24");
carp Dumper($ft);
my $foo = $ft->getIngressFlowsInTimeRange( time - 30, time );

print Dumper($foo);
print "Count: " . scalar(@$foo) . "\n";

my $bar = $ft->getEgressFlowsInTimeRange( time - 30, time );

print Dumper($bar);
print "Count: " . scalar(@$bar) . "\n";



