use strictures 1;

use feature 'say';
my $bind = $ARGV[0] || 'tcp://127.0.0.1:5510';

## REP server that responds to "ping"

use POE;
use POEx::ZMQ3::Replier;

POE::Session->create(
  heap => POEx::ZMQ3::Replier->new,
  package_states => [
    main => [ qw/
      _start
      zeromq_got_request
    / ],
  ],
);

sub _start {
  my ($kern, $zrep) = @_[KERNEL, HEAP];
  $zrep->start( $bind );
  $kern->post( $zrep->session_id, 'subscribe' );
}

sub zeromq_got_request {
  my ($kern, $zrep, $sess) = @_[KERNEL, HEAP, SESSION];
  my $data = $_[ARG0];
  if ($data =~ /^ping/) {
    say "Got PING, sending PONG";
    $zrep->reply('pong!')
  } else {
    warn "Don't know what to do with request $data"
  }
}

$poe_kernel->run;
