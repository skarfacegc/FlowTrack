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
# TODO: Docs
# TODO: Cleanup Comments etc.
# TODO: ** Release ** 0.01
# TODO: Error Checking config file
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
use Data::Dumper;

use FT::Configuration;
use FT::FlowCollector;
use FT::FlowTrackWeb;
use FT::Reporting;

use POSIX ":sys_wait_h";
use Mojo::Server;
use Mojo::Server::Daemon;

# get things started.  Init configs/loops etc. Starts all the processes.
main();

sub main
{
    my $command_hash;
    my $children;
    my $command_line;
    my $config_file;
    my $printHelp;
    my $logger;

    # Set to 0 on sigterm
    my $keepAlive = 1;

    # handle the command line
    $command_line = GetOptions( "config=s" => \$config_file );

    # Mojolicious consumes --help and -h off of @ARGV making it hard
    # to use getopt properly.  HOWEVER, it does set MOJO_HELP.  We'll use
    # that.  Still kinda dumb though.
    if ( $ENV{MOJO_HELP} )
    {
        print "\t--help\t\t\t This message\n";
        print "\t--config=flowTrack.conf\t Location of config file (defaults to ./flowTrack.conf)\n";

        exit;
    }

    # init the config file
    FT::Configuration::setConf($config_file);

    # Init our log4perl configuration.
    my $config = FT::Configuration::getConf();
    if ( exists $config->{logging_conf} && -r $config->{logging_conf} )
    {
        Log::Log4perl->init_and_watch( $config->{logging_conf} );
        $logger = get_logger();
        $logger->debug("Loaded l4p configuration");
    }

    #
    # Start launching processes
    #

    # Daemonize ourself
    if (fork)
    {
        # Original process
        close(STDOUT);
        close(STDIN);
        close(STDERR);
        exit;
    }

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

        $logger->info("Child died");
    };

    local $SIG{TERM} = sub { $keepAlive = 0 };

    # Here is where we define which routines to fork and run.
    # perhaps a bit of over kill, but seems easier to add and change
    # stuff this way.
    $command_hash->{runReports} = \&runReports;
    $command_hash->{Collector}  = \&startCollector;
    $command_hash->{WebServer}  = \&startWebserver;

    while ($keepAlive)
    {
        foreach my $process ( keys %$command_hash )
        {
            # We don't want to fork or try starting the process
            # if it's already running
            if ( !isRunning( $process, $children ) )
            {
                my $pid = fork;

                if ($pid)
                {
                    # Parent

                    # save our pid file
                    savePIDFile( "main", $$ );

                    # Add the child to the children hash
                    # this is used to keep track of who's running or not
                    # (as well as who to kill in cleanup)
                    $children->{$pid} = $process;
                    next;
                }

                # Child
                $logger->info("Starting: $process ($PID)");

                # Save the pidfile for the process
                savePIDFile( $process, $$ );

                # Run the command
                &{ $command_hash->{$process} };

                # Likely that the below will never get called
                $logger->info("Exiting: $process ($$)");
                exit;
            }

        }

        # Pause a bit before we go back through the loop
        # the signals will wake us up though.
        sleep 15;
    }

    #
    # Cleanup
    #
    $logger->info( "Exiting, killing off children " . join( " ", keys %$children ) );
    kill( 2, keys %$children );

    # Remove the pid files
    removePIDFile('main');
    foreach my $child ( keys %$children )
    {
        removePIDFile( $children->{$child} );
    }

    exit;
}

# This is the bit that actually does the flow collection
# is just a net::server listener
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
    
    $daemon->app( FT::FlowTrackWeb->new() );
    $daemon->run();

    return;
}

# This sub handles running the reports.
# The report loop runs every 5 minutes, on the 5 minute boundary, so at startup we
# figure out how many seconds it is to the next 5 minute boundary and sleep for that long.
#
# Reports don't do anything right now.  Will update RRDs consolidate stats etc at a later point
# in time.
sub runReports
{
    my $logger = get_logger();
    my $config = FT::Configuration::getConf();
    my $reports = FT::Reporting->new($config);

    while (1)
    {
        # sleep to the next 5 minute boundary
        sleep( ( $config->{reporting_interval} * 60 ) - ( time % ( $config->{reporting_interval} * 60 ) ) );

        $logger->info('Running report');
        $reports->runReports();

        sleep( $config->{reporting_interval} * 60 );
    }

    return;
}

# Writes out pid files
sub savePIDFile
{
    my ( $process, $pid ) = @_;
    my $config = FT::Configuration::getConf();
    my $logger = get_logger();

    if ( -w $config->{pid_files} )
    {
        open( my $fh, ">", $config->{pid_files} . "/$process.pid" )
          || $logger->logconfess("Couldn't open " . $config->{pid_files} . "/$process.pid: $!");
        print $fh "$pid\n";
        close($fh);

    }
    else
    {
        $logger->logconfess($config->{pid_files} . " is either missing or not writable");
    }

    return;
}

# Removes the pid files
sub removePIDFile
{
    my ($process) = @_;
    my $config    = FT::Configuration::getConf();
    my $logger    = get_logger();

    my $filename = $config->{pid_files} . "/$process.pid";
    unlink $filename or $logger->warn("Couldn't remove $filename");

    return;
}

# Figure out whether a given pid is running
# This isn't perfect ()
sub isRunning
{
    my ( $process, $children ) = @_;

    my $logger = get_logger();

    foreach my $pid ( keys %$children )
    {
        if ( $children->{$pid} eq $process )
        {

            # Kill 0 should tell us if the process is still running
            if ( !kill( 0, $pid ) )
            {
                $logger->warn("Looks like $process died unexpectedly.");
                delete $children->{$pid};
                return 0;
            }
            else
            {
                return 1;
            }
        }
    }

    # If we get here the process wasn't in the children hash, so we
    # should assume it's not running
    return 0;

}
