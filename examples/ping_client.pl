use strictures 1;
use feature 'say';

## FIXME
##  Current bug exhibited:
##   - Sent PING    (client)
##    * Sent PONG   (server)
##   - Got PONG
##   - Sent PING
##    * Sent PONG
##  < PONG never received by client
##  Session is still alive (timers fire)
##  Server is responsive


my $addr = $ARGV[0] || 'tcp://127.0.0.1:5510';

## REQ client that talks to ping_server.pl

use POE;
use POEx::ZMQ3::Requestor;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      send_ping
      zeromq_connected_to
      zeromq_registered
      zeromq_got_reply
    / ],
  ],
);

sub _start {
  $_[HEAP] = POEx::ZMQ3::Requestor->new;
  $_[HEAP]->start( $addr );
  $_[KERNEL]->post( $_[HEAP]->session_id, 'subscribe' );
}

sub zeromq_connected_to {}
sub zeromq_registered {
  my ($kern, $zrequest) = @_[KERNEL, HEAP];
  $kern->yield( 'send_ping' );
}

sub zeromq_got_reply {
  my ($kern, $zrequest, $sess) = @_[KERNEL, HEAP, SESSION];
  my $data = $_[ARG0];
  say "Got PONG";
  $kern->delay_add( 'send_ping' => 1 );
}

sub send_ping {
  my ($kern, $zrequest) = @_[KERNEL, HEAP];
  say "Sending PING";
  $zrequest->request( 'ping!' );
}

$poe_kernel->run;
