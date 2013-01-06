use strictures 1;

use feature 'say';
my $bind = $ARGV[0] || 'tcp://127.0.0.1:5510';

## REP server that responds to "ping"

use POE;
use POEx::ZMQ3::Replier;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      zeromq_got_request
    / ],
  ],
);

sub _start {
  $_[HEAP] = POEx::ZMQ3::Replier->new;
  $_[HEAP]->start( $bind );
  $_[KERNEL]->post( $_[HEAP]->session_id, 'subscribe' );
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
