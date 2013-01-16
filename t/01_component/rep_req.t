use Test::More;
use strict; use warnings qw/FATAL all/;
use 5.10.1;
my $addr = 'inproc://repreqtest';

use POE;

use_ok 'POEx::ZMQ3::Sockets';

my $got = {};
my $expected = {
  'REP got request' => 10,
  'REQ got reply'   => 10,
};
POE::Session->create(
  heap => POEx::ZMQ3::Sockets->new,
  package_states => [
    main => [ qw/
      _start
      zmqsock_registered
      zmqsock_recv
      timeout
    / ],
  ],
);

alarm 20;
sub _start {
  $_[KERNEL]->sig( ALRM => 'timeout' );
  my $zmq = $_[HEAP];
  $zmq->start;
  $poe_kernel->post( $zmq, 'subscribe', 'all' );
}

sub timeout {
  $_[HEAP]->stop;
  fail "Timed out"
}

sub zmqsock_registered {
  my $zmq = $_[HEAP];
  $zmq->create( 'server', 'REP' );
  $zmq->create( 'client', 'REQ' );
  $zmq->bind( 'server', $addr );
  $zmq->connect( 'client', $addr );
  $zmq->write( 'client', 'A request' );
}

sub zmqsock_recv {
  my ($kern, $zmq) = @_[KERNEL, HEAP];
  my ($alias, $data) = @_[ARG0 .. $#_];

  for ($alias) {
    when ('server') {
      ## Got a REQ on our REP server
      $got->{'REP got request'}++;
      $zmq->write( $alias, 'A reply' )
    }

    when ('client') {
      ## Got a REP on our REQ server
      $got->{'REQ got reply'}++;
      if ($got->{'REQ got reply'} == $expected->{'REQ got reply'}) {
        $zmq->stop;
        return
      }
      $zmq->write( $alias, 'A request' )
    }
  }
}


$poe_kernel->run;
POEx::ZMQ3::Context->term;
is_deeply $got, $expected, 'component looks ok';
done_testing;
