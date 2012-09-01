#!/usr/bin/env perl
#
# Copyright 2012 Andrew Williams <andrew@manor.org>
#
# Start services
#   Main Collection Routines start in FT/FlowCollector.pm
#
# For Documentation & License see the README
#
# TODO: Daemonize
# TODO: Check for dead procs
#
use strict;
use warnings;
use English;
use Carp;

use FT::FlowCollector;

# Loop and fork!
main();
sub main
{
    my $command_hash;
    my @pids;

    # Here is where we define which routines to fork and run.
    # perhaps a bit of over kill, but seems easier to add and change 
    # stuff this way.
    $command_hash->{Collector} = \&startCollector;
    $command_hash->{runReports} = \&runReports;

    foreach my $process ( keys %$command_hash )
    {

        carp "$process";
        my $pid = fork;

        if ($pid)
        {
            #parent
            push @pids, $pid;
            next;
        }

        #child
        carp "Starting: $process ($PID)";

        # Run the command
        &{ $command_hash->{$process} };

        croak "Exiting process ($$)";
    }

    wait for @pids;
    carp "Exiting";
}

sub startCollector
{
    FT::FlowCollector::CollectorStart();
}

# This sub handles running the reports.
# The report loop runs every 5 minutes, on the 5 minute boundry, so at startup we
# figure out how many seconds it is to the next 5 minute boundry and sleep for that long.
sub runReports
{
    carp "Starting report loop";
    while (1)
    {
        # sleep to the next 5 minute boundry
        sleep 300 - (time % 300);

        carp "Running report " . scalar(localtime());

        sleep 300;
    }
}
