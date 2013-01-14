use Test::More;
use strict; use warnings qw/FATAL all/;
use 5.10.1;
use Test::TCP 'empty_port';
my $addr = 'tcp://127.0.0.1:'.empty_port;

use POE;

use_ok 'POEx::ZMQ3::Sockets';

my $got = {};
my $expected = {
  'SUB got msg' => 1,
};

POE::Session->create(
  heap => POEx::ZMQ3::Sockets->new,
  package_states => [
    main => [ qw/
      _start
      zmqsock_registered
      zmqsock_recv
      publish_things
      timeout
    / ],
  ],
);

alarm 60;
sub _start {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  $kern->sig( ALRM => 'timeout' );
  $zmq->start;
  $kern->post( $zmq->session_id, subscribe => 'all' );
}

sub timeout {
  $_[KERNEL]->alarm_remove_all;
  $_[HEAP]->stop;
  fail "Timed out"
}

sub zmqsock_registered {
  my ($kern, $zmq) = @_[KERNEL, HEAP];

  $zmq->create( 'server', 'PUB' );
  $zmq->create( 'client', 'SUB' );

  $zmq->bind( 'server', $addr );
  $zmq->connect( 'client', $addr );
  $zmq->set_zmq_subscribe( 'client' );

  $kern->yield( 'publish_things' );
}

sub publish_things {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  $zmq->write( 'server', 'A published message' );
  $kern->delay( 'publish_things' => 0.5 )
}

sub zmqsock_recv {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  my ($alias, $data) = @_[ARG0 .. $#_];

  fail "How did we recv on our PUB socket?"
    if $alias eq 'server';

  $got->{'SUB got msg'}++;

  if ($got->{'SUB got msg'} == $expected->{'SUB got msg'}) {
    $kern->delay( 'publish_things' );
    $zmq->stop;
  }
}

$poe_kernel->run;
POEx::ZMQ3::Context->term;
is_deeply $got, $expected, 'pub-sub pair looks ok';
done_testing

