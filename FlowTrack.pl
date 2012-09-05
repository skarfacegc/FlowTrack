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
# TODO: Docs
# TODO: Fix the no-data request in Main.pm  (browser shouldn't hang on no data
# TODO: Sane loggin
# TODO: Error Checking config file
#
#
#
use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use English;
use Carp;
use Getopt::Long;

use FT::Configuration;
use FT::FlowCollector;
use FT::FlowTrackWeb;
use Mojo::Server;
use Mojo::Server::Daemon;
use Mojolicious::Commands;
use MojoX::Log::Log4perl;

# Loop and fork!
main();

sub main
{
    my $command_hash;
    my @pids;
    my $command_line;
    my $config_file;
    my $logger;

    # Handle the command line and prime the configuration object
    # We'll call new on the config object in other places, but
    # We don't actually re-read the config file, just get the object back
    # yay singletons
    #
    # Defaults to ./flowTrack.conf  (set in the Configuration package)
    $command_line = GetOptions( "config=s" => \$config_file );
    FT::Configuration::setConf($config_file);

    #
    # Init our log4perl configuration.
    #
    my $config = FT::Configuration::getConf();
    if ( exists $config->{logging_conf} && -r $config->{logging_conf} )
    {
        Log::Log4perl->init( $config->{logging_conf} );
        $logger = get_logger();
        $logger->debug("Loaded l4p configuration");

    }

    # Here is where we define which routines to fork and run.
    # perhaps a bit of over kill, but seems easier to add and change
    # stuff this way.
    $command_hash->{Collector}  = \&startCollector;
    $command_hash->{runReports} = \&runReports;
    $command_hash->{WebServer}  = \&startWebserver;

    foreach my $process ( keys %$command_hash )
    {

        my $pid = fork;

        if ($pid)
        {
            #parent
            push @pids, $pid;
            next;
        }

        #child
        $logger->info("Starting: $process ($PID)");

        # Run the command
        &{ $command_hash->{$process} };

        $logger->info("Exiting: $process ($$)");
        die;
    }

    wait for @pids;
    $logger->debug('fin');
}

sub startCollector
{
    FT::FlowCollector::CollectorStart();
}

# Setups the mojo server.  The application code lives in FlowTrackWeb.pm
sub startWebserver
{
    my $config = FT::Configuration::getConf();
    my $daemon = Mojo::Server::Daemon->new( listen => [ 'http://*:' . $config->{web_port} ] );
    my $app    = FT::FlowTrackWeb->new();
    
    $app->log( MojoX::Log::Log4perl->new($config->{logging_conf}));

    $app->secret('3305CA4A-DE4D-4F34-9A38-F17E0A656A25');
    $daemon->app( FT::FlowTrackWeb->new() );
    $daemon->run();
}

# This sub handles running the reports.
# The report loop runs every 5 minutes, on the 5 minute boundry, so at startup we
# figure out how many seconds it is to the next 5 minute boundry and sleep for that long.
sub runReports
{
    my $logger = get_logger();
    while (1)
    {
        # sleep to the next 5 minute boundry
        sleep 300 - ( time % 300 );

        $logger->debug('Running report');

        sleep 300;
    }
}
