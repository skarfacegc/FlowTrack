package FT::Configuration;
use strict;
use warnings;
use Log::Log4perl qw(get_logger);

use Data::Dumper;
use Carp;
use YAML;

# This is going to be a singleton.
my $oneTrueSelf;

sub setConf
{

    if ( !defined $oneTrueSelf )
    {
        my $config_file = shift();
        my $config_struct;
        my $ret_struct;
        my $logger = get_logger();

        $config_file = defined($config_file) ? $config_file : "./flowTrack.conf";

        if ( !-r $config_file )
        {
            $logger->fatal( "Couldn't read " . $config_file );
            die "Couldn't read " . $config_file;
        }

        $config_struct = YAML::LoadFile($config_file) or $logger->logdie("Error parsing " . $config_file);

        $oneTrueSelf = $config_struct;
        $oneTrueSelf->{ConfigFile} = $config_file;
    }

    return $oneTrueSelf;
}

sub getConf
{
    my $logger = get_logger();

    # Try to set a configuration if we don't already have one.
    if ( !defined($oneTrueSelf) )
    {
        setConf();

        if ( !defined($oneTrueSelf) )
        {
            $logger->logdie("Config not loaded.");
        }
    }

    return $oneTrueSelf;
}

1;
