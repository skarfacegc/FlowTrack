#!/usr/bin/perl

use TAP::Harness;

my %args = (
    verbosity => 1, 
    lib => [ 'ft' ],
    show_count => 1,
    color => 1, 
    );



my $harness = TAP::Harness->new(\%args);

my $aggregator = $harness->runtests(<t/*>);


