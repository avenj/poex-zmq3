use strictures 1;
use 5.10.1;

my $bind = $ARGV[0] || 'tcp://127.0.0.1:5511';

use POE;
use POEx::ZMQ3::Subscriber;

POE::Session->create(
  heap => POEx::ZMQ3::Subscriber->new,
  package_states => [
    main => [ qw/
      _start
      zeromq_received
    / ],
  ],
);

sub _start {
  my ($kern, $zsub) = @_[KERNEL, HEAP];
  $zsub->start( $bind );
  $kern->post( $zsub => 'subscribe' );
}

sub zeromq_received {
  my ($kern, $zsub, $data) = @_[KERNEL, HEAP, ARG0];
  say "Server says: $data";
}

$poe_kernel->run;
