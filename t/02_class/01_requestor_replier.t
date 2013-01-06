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
  'got got_request'  => 10,
  'request looks ok' => 10,
  'got got_reply'    => 10,
  'reply looks ok'   => 10,
};

alarm 10;
POE::Session->create(
  inline_states => {
    _start => sub {
      $_[KERNEL]->sig(ALRM => 'fail');
      $zreply->start( $addr );
      $zrequest->start( $addr );
      $poe_kernel->post( $zreply->session_id, 'subscribe' );
      $poe_kernel->post( $zrequest->session_id, 'subscribe' );
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
      $zreply->reply( 'pong!' )
    },

    zeromq_got_reply => sub {
      $got->{'got got_reply'}++;
      $got->{'reply looks ok'}++
        if $_[ARG0] eq 'pong!';

      if ($got->{'got got_reply'} == 10) {
        $_[KERNEL]->call( $_[SESSION], 'stopit' );
        return
      }
      $zrequest->request( 'ping!' )
    },

    stopit => sub {
      $poe_kernel->alarm_remove_all;
      $zrequest->stop;
      $zreply->stop;
    },

    fail => sub {
      $_[KERNEL]->call( $_[SESSION], 'stopit' );
      fail "Timed out"
    },
  }
);

$poe_kernel->run;

is_deeply $got, $expected, 'request/reply interaction ok';

done_testing;
