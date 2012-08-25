#!/usr/bin/env perl
#
#
use strict;
use warnings;
use XML::Simple;
use Data::Dumper;


my $ref = XMLin("/Users/andrew/Development/FlowTrack/portlist.xml");

print Dumper($ref);cd 
