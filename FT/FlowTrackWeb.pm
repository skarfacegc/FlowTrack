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

    $r->get(
        '/' => sub {
            my $self = shift;

            #        my $foo = $self->param('foo');
            $self->render( text => "Howdy!!" );
        }
    );
}

1;
