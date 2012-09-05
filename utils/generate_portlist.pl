#!/usr/bin/env perl
#
#
use strict;
use warnings;
use Log::Log4perl qw(get_logger);

use XML::Simple;
use Data::Dumper;


my $ref = XMLin("/Users/andrew/Development/FlowTrack/portlist.xml");

print Dumper($ref);
