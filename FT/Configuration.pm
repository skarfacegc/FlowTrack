package FT::Configuration;
use strict;
use warnings;
use Data::Dumper;
use Carp;
use YAML;

# This is going to be a singleton.
my $oneTrueSelf;

sub setConf
{
    if(!defined $oneTrueSelf)
    {
        my $config_file = shift();
        my $config_struct;
        my $ret_struct;

 
        $config_file = defined($config_file) ? $config_file : "./flowTrack.conf";

        croak "Couldn't read " . $config_file if(!-r $config_file );

        $config_struct = YAML::LoadFile($config_file) or croak "Error parsing " . $config_file;

        $oneTrueSelf = $config_struct;
        $oneTrueSelf->{ConfigFile} = $config_file;
    }

    return $oneTrueSelf;
}


sub getConf
{
    if(!defined($oneTrueSelf))
    {
        croak "Config not loaded.";
    }

    return $oneTrueSelf;
}

1;