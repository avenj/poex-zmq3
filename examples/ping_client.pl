use strictures 1;
use feature 'say';
my $addr = $ARGV[0] || 'tcp://127.0.0.1:5510';

## REQ client that talks to ping_server.pl

use POE;
use POEx::ZMQ3::Requestor;

POE::Session->create(
  heap => POEx::ZMQ3::Requestor->new,
  package_states => [
    main => [ qw/
      _start
      send_ping
      zeromq_registered
      zeromq_got_reply
    / ],
  ],
);

sub _start {
  my ($kern, $zrequest) = @_[KERNEL, HEAP];
  $zrequest->start( $addr );
  $kern->post( $zrequest => 'subscribe' );
}

sub zeromq_registered {
  my ($kern, $zrequest) = @_[KERNEL, HEAP];
  $kern->yield( 'send_ping' );
}

sub zeromq_got_reply {
  my ($kern, $zrequest) = @_[KERNEL, HEAP];
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
