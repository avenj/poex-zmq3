use Test::More;
use strict; use warnings qw/FATAL all/;
use 5.10.1;
use Test::TCP 'empty_port';
my $addr = 'tcp://127.0.0.1:'.empty_port;

use POE;

use_ok 'POEx::ZMQ3::Sockets';

my $got = {};
my $expected = {
  'SUB got msg'             => 20,
  'SUB got correct header'  => 20,
  'SUB got correct content' => 20,
};

POE::Session->create(
  heap => POEx::ZMQ3::Sockets->new,
  package_states => [
    main => [ qw/
      _start
      zmqsock_registered
      zmqsock_multipart_recv
      publish_things
      timeout
    / ],
  ],
);

alarm 20;
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
  $zmq->set_zmq_subscribe( 'client', 'A' );

  $kern->yield( 'publish_things' );
}

sub publish_things {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  $zmq->write_multipart( server =>
    'A',
    'This is message A'
  );
  $zmq->write_multipart( server =>
    'B',
    'This is message B'
  );
  $kern->delay( 'publish_things' => 0.01 )
}

sub zmqsock_multipart_recv {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  my ($alias, $parts) = @_[ARG0 .. $#_];

  fail "How did we recv on our PUB socket?"
    if $alias eq 'server';

  my ($envel, $content) = @$parts;

  fail "Should not have received from unsubscribed header B"
    if $envel eq 'B';

  $got->{'SUB got correct header'}++ 
    if $envel eq 'A';
  $got->{'SUB got correct content'}++
    if $content eq 'This is message A';

  $got->{'SUB got msg'}++;
  if ($got->{'SUB got msg'} == $expected->{'SUB got msg'}) {
    $kern->delay( 'publish_things' );
    $zmq->stop;
  }
}

$poe_kernel->run;
is_deeply $got, $expected, 'pub-sub pair looks ok';
done_testing

