#!/usr/bin/env perl

#
# This isn't particularly pretty, but it just runs all of the tests in t/
# All it needs to do at this point
#
use strict;
use warnings;
use TAP::Harness;

my %args = (
    verbosity  => 1,
    lib        => ['ft'],
    show_count => 1,
    color      => 1,
);

my $harness = TAP::Harness->new( \%args );


my $aggregator = $harness->runtests(glob("t/*.t"));

