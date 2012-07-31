#!/usr/bin/env perl

use FT::FlowTrack;
use Data::Dumper;


my $ft = FT::FlowTrack->new("./Data",1, "FlowTrack.sqlite", "192.168.1.0/24");


my $foo = $ft->getFlowsTimeRange(time - 30, time);

print Dumper($foo);
print "Count: " . scalar(@$foo) . "\n";
