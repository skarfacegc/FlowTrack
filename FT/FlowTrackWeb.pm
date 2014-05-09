package FT::FlowTrackWeb;

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

    $r->route('/')->name('index')->to( controller => 'main', action => 'indexPage' );

    $r->route('/FlowsForLast/:timerange')->to( controller => 'main', action => 'simpleFlows' );
    $r->route('/json/FlowsForLast/:timerange')->to( controller => 'main', action => 'simpleFlowsJSON' );
    $r->route('/json/LastHourTotals/:bucketsize')->to( controller => 'main', action => 'aggergateBucketJSON' );
    $r->route('/json/topTalkers/:talker_count')->to(controller => 'main', action => 'topTalkersJSON');

    return;
}

1;
