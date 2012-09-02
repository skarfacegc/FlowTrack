package FT::FlowTrackWeb;

use strict;
use warnings;
use Carp;
use Mojo::Base 'Mojolicious';
use Data::Dumper;
use vars '$AUTOLOAD';

sub startup
{
    my $self = shift();

    my $r = $self->routes;

    $r->route('/')->name('index')->to( controller => 'main', action => 'index' );

    $r->route('/FlowsForLast/:timerange')->to( controller => 'main', action => 'simpleFlows' );
    $r->route('/json/FlowsForLast/:timerange')->to( controller => 'main', action => 'simpleFlowsJSON' );
}

1;
