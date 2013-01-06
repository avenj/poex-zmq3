use Test::More;
use Test::TCP 'empty_port';
my $addr = 'tcp://127.0.0.1:' . empty_port;

use POE;

use_ok 'POEx::ZMQ3::Requestor';
use_ok 'POEx::ZMQ3::Replier';

my $zrequest = POEx::ZMQ3::Requestor->new;
my $zreply   = POEx::ZMQ3::Replier->new;

my $got = {};
my $expected = {
  'got connected_to' => 1,
  'got replying_on'  => 1,
  'got got_request'  => 1,
  'request looks ok' => 1,
  'got got_reply'    => 1,
  'reply looks ok'   => 1,
};

POE::Session->create(
  inline_states => {
    _start => sub {
      $zreply->start( $addr );
      $poe_kernel->post( $zreply->session_id, 'subscribe' );
      $zrequest->start( $addr );
      $poe_kernel->post( $zrequest->session_id, 'subscribe' );
      $poe_kernel->delay( stopit => 10 );
    },

    zeromq_connected_to => sub {
      $got->{'got connected_to'} = 1;
      $zrequest->request( 'ping!' );
    },

    zeromq_replying_on => sub {
      $got->{'got replying_on'} = 1;
    },

    zeromq_got_request => sub {
      $got->{'got got_request'}++;
      $got->{'request looks ok'}++
        if $_[ARG0] eq 'ping!';
      $zreply->yield( sub { $zreply->reply( 'pong!' ) });
    },

    zeromq_got_reply => sub {
      $got->{'got got_reply'}++;
      $got->{'reply looks ok'}++
        if $_[ARG0] eq 'pong!';

      $_[KERNEL]->yield( 'stopit' );
    },

    stopit => sub {
      $poe_kernel->alarm_remove_all;
      $zrequest->stop;
      $zreply->stop;
    },
  }
);

$poe_kernel->run;

is_deeply $got, $expected, 'request/reply interaction ok';

done_testing;
