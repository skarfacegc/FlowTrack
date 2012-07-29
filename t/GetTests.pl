#!/usr/bin/env perl

use FT::FlowTrack;
use Data::Dumper;


my $ft = FT::FlowTrack->new("./Data",1, "FlowTrack.sqlite", "192.168.1.0/24");


my $foo = $ft->getFlowsTimeRange(0, 1342879454);

print Dumper($foo);

