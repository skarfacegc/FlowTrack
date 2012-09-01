package FT::FlowTrackWeb;

use strict;
use warnings;

use Mojo::Server::Daemon;




sub runServer
{
    my $daemon = Mojo::Server::Daemon->new( listen => ['http://*:5656'] );
    $daemon->unsubscribe('request');
    $daemon->on(
        request => sub {
            my ( $daemon, $tx ) = @_;

            # Request
            my $method = $tx->req->method;
            my $path   = $tx->req->url->path;

            # Response
            $tx->res->code(200);
            $tx->res->headers->content_type('text/plain');
            $tx->res->body("$method request for $path!");

            # Resume transaction
            $tx->resume;
        }
    );
    $daemon->run;
}

1;
