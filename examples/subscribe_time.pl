use strictures 1;
use 5.10.1;

my $bind = $ARGV[0] || 'tcp://127.0.0.1:5511';

use POE;
use POEx::ZMQ3::Subscriber;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      zeromq_received
    / ],
  ],
);

sub _start {
  $_[HEAP] = POEx::ZMQ3::Subscriber->new;
  $_[HEAP]->start( $bind );
  $_[KERNEL]->post( $_[HEAP]->session_id, 'subscribe' );
}

sub zeromq_received {
  my ($kern, $zsub, $data) = @_[KERNEL, HEAP, ARG0];
  say "Server says: $data";
}

$poe_kernel->run;
