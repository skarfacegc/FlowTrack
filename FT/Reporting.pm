# This module handles some of the longer term statistics gathering.
# RRD Graphs, tracking common talkers, etc.  It deals with the secondary data
#
package FT::Reporting;
use strict;
use warnings;
use Log::Log4perl qw{get_logger};
use FT::Configuration;
use FT::FlowTrack;
use parent qw{FT::FlowTrack};
use Data::Dumper;




#
# All new really does here is create an FT object, and initalize the config
sub new
{
    my $class = shift;
    my ($config) = @_;

    return $class->SUPER::new($config->{data_dir}, $config->{internal_network} );

}


sub runReports
{
    my $self = shift;
    my $logger = get_logger();

    $self->getMostRecentTalkers();

    return;
}

sub getMostRecentTalkers
{
    my $self = shift();
    my ($reporting_interval) = @_;

    my $logger = get_logger();
    my $dbh = $self->_initDB();
    my $ret_list;

    if(!defined $reporting_interval)
    {
        my $config = FT::Cofiguration::getConf();
        $reporting_interval = $config->{reporting_interval};

        if(!defined $reporting_interval)
        {
            $logger->fatal('could not determine reporting interval') && die;
        }
    }

    my $start_time = time - ( $reporting_interval * 60 );

    my $sql = qq{
                SELECT DISTINCT
                    count(*) as total_flows, 
                    src_ip, 
                    dst_ip
                FROM
                    raw_flow
                WHERE
                    fl_time >= ?
                GROUP BY
                    src_ip,dst_ip

            };

    my $sth = $dbh->prepare($sql);
    $sth->execute($start_time);

    while ( my $ref = $sth->fetchrow_hashref )
    {
        push @$ret_list, $ref;
    }

    return $ret_list;
}

1;
