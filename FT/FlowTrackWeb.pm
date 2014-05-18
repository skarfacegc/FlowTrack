package FT::FlowTrackWeb;
#
# This file contains the routes used by Mojo.  
#

use strict;
use warnings;
use Log::Log4perl qw(get_logger);
use Carp;

use Mojo::Base 'Mojolicious';
use Mojolicious::Static;
use Data::Dumper;
use vars '$AUTOLOAD';

sub startup
{
    my $self = shift;

    # Serve up the static pages
    $self->static( Mojolicious::Static->new() );
    push( @{ $self->static->paths }, './html' );

    # Load plugins
    $self->plugin('DefaultHelpers');

    my $r = $self->routes;

    #
    # User facing pages
    #

    # Index
    $r->route('/')->name('index')->to( controller => 'main', action => 'indexPage' );

    # Table view
    $r->route('/FlowsForLast/:timerange')->to( controller => 'main', action => 'tableView' );


    #
    # JSON services
    #

    # This is mainly used by the table view
    $r->route('/json/FlowsForLast/:timerange')->to( controller => 'main', action => 'tableViewJSON' );

    # Main graph retrevial routine
    $r->route('/json/GraphTotalsForLast/:bucketsize')->to( controller => 'main', action => 'aggergateBucketJSON' );

    # Gets the data for the talker grid
    $r->route('/json/topTalkers/:talker_count')->to( controller => 'main', action => 'topTalkersJSON' );

    # DNS Resolver
    $r->route('/json/dns/#dns')->to( controller => 'main', action => 'Resolve' );

    return;
}

1;
