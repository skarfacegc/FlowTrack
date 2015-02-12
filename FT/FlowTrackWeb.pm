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


    #
    # Data for text and tabular views
    #
    # This is mainly used by the table view
    $r->route('/json/FlowsForLast/:timerange')->to( controller => 'main', action => 'tableViewJSON' );


    # Gets the data for the talker grid
    $r->route('/json/topTalkers/:talker_count')->to( controller => 'main', action => 'topTalkersJSON' );

    #
    # Graph data
    #

    # Main graph retrevial routine
    $r->route('/json/GraphTotalsForLast/:minutes/:bucketsize')
      ->to( controller => 'main', action => 'aggergateBucketJSON' );

    # per ip pair flow data (same format as graphTotals, but for an individual pair)
    $r->route('/json/TalkerGraphTotalsForLast/#ipa/#ipb/:minutes/:bucketsize')
      ->to( controller => 'main', action => 'aggregateBucketTalkersJSON' );


    #
    # Utilities
    #

    # DNS Resolver
    $r->route('/json/dns/#dns')->to( controller => 'main', action => 'Resolve' );


    return;
}

1;
