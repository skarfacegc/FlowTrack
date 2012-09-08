#!/usr/bin/env perl
#
# Copyright 2012 Andrew Williams <andrew@manor.org>
#
# Start services
#   Main Collection Routines start in FT/FlowCollector.pm
#
# For Documentation & License see the README
#
# Basic Roadmap
# -------------
# TODO: Sane logging
# TODO: Daemonize
# TODO: Kill Children on signal
# TODO: Fix the no-data request in Main.pm  (browser shouldn't hang on no data)
# TODO: Check for dead procs
# TODO: Docs
# TODO: Error Checking config file
# TODO: Cleanup dead files
# TODO: ** Release ** 0.01
# TODO: Deeper server interaction on datatables
# TODO: Sparkline page
# TODO: Long term RRD graphs
# TODO: Add index support to the schema definitions
# TODO: ** Release ** 0.02

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use English;
use Carp;
use Getopt::Long;

use FT::Configuration;
use FT::FlowCollector;
use FT::FlowTrackWeb;
use POSIX ":sys_wait_h";
use Mojo::Server;
use Mojo::Server::Daemon;
use Mojolicious::Commands;
use MojoX::Log::Log4perl;

# Loop and fork!
main();

sub main
{
    my $command_hash;
    my $children;
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

    # Daemonize ourself
    if (fork)
    {
        # Original process
        close(STDOUT);
        close(STDIN);
        close(STDERR);
        exit;
    }

    savePIDFile("main", $$);

    #
    # Signal handlers
    # These could probably be improved, but they seem to work for now.
    #
    local $SIG{CHLD} = sub {
        my $kid;

        do
        {
            $kid = waitpid( -1, WNOHANG );
        } while $kid > 0;

        $logger->warn("Child died");
    };

    local $SIG{TERM} = sub {
        $logger->warn( "Caught TERM, killing " . join( " ", keys %$children ) );
        kill( 2, keys %$children );
        exit;
    };

    # Here is where we define which routines to fork and run.
    # perhaps a bit of over kill, but seems easier to add and change
    # stuff this way.
    $command_hash->{runReports} = \&runReports;
    $command_hash->{Collector}  = \&startCollector;
    $command_hash->{WebServer}  = \&startWebserver;

    foreach my $process ( keys %$command_hash )
    {
        my $pid = fork;

        if ($pid)
        {
            $children->{$pid}{$process} = 1;
            next;
        }

        #child
        $logger->info("Starting: $process ($PID)");

        savePIDFile($process, $$);

        # Run the command
        &{ $command_hash->{$process} };

        $logger->info("Exiting: $process ($$)");
        exit;
    }

    wait for keys %$children;
    $logger->debug('fin');

    return;
}

sub startCollector
{
    FT::FlowCollector::CollectorStart();
    return;
}

# Setups the mojo server.  The application code lives in FlowTrackWeb.pm
sub startWebserver
{
    my $config = FT::Configuration::getConf();
    my $daemon = Mojo::Server::Daemon->new( listen => [ 'http://*:' . $config->{web_port} ] );
    my $app    = FT::FlowTrackWeb->new();

    $app->secret('3305CA4A-DE4D-4F34-9A38-F17E0A656A25');
    $daemon->app( FT::FlowTrackWeb->new() );
    $daemon->run();

    return;
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

    return;
}

sub savePIDFile
{
    my ( $process, $pid ) = @_;
    my $config = FT::Configuration::getConf();
    my $logger = get_logger();

    if ( -w $config->{pid_files} )
    {
        open( my $fh, ">", $config->{pid_files} . "/$process.pid" )
          || croak "Couldn't open " . $config->{pid_files} . "/$process.pid: $!";
        print $fh "$pid\n";
        close($fh);

    }
    else
    {
        croak $config->{pid_files} . " is either missing or not writable";
    }

    return;
}

