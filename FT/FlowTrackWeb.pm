package FT::FlowTrackWeb;

use POE;
use POE::Component::Server::HTTP;
use HTTP::Status qw(:constants);

# This starts the server
# Should be called via WheelRun from FlowTrack.pm
sub ServerStart
{
    POE::Kernel->stop();

    warn "Starting server";

    $httpd = POE::Component::Server::HTTP->new(
        Port           => 8000,
        ContentHandler => { '/' => \&homepage },
        Headers        => { Server => 'My Server' },
    );
    POE::Kernel->run();

}

sub homepage
{
    my ( $request, $response ) = @_;
    $response->code(RC_OK);
    $response->content( "Hi, you fetched " . $request->uri );
    return RC_OK;
}
1;
