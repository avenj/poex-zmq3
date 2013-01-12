use Test::More;
use Test::TCP 'empty_port';
my $addr = 'tcp://127.0.0.1:' . empty_port;

use POE;

use_ok 'POEx::ZMQ3::Subscriber';
use_ok 'POEx::ZMQ3::Publisher';

my $zsub = POEx::ZMQ3::Subscriber->new;
my $zpub = POEx::ZMQ3::Publisher->new;

my $got = {};
my $expected = {
  'got publishing_on' => 1,
  'got subscribed_to' => 1,
  'received published'      => 5,
  'published data looks ok' => 5,
};

alarm 10;
POE::Session->create(
  inline_states => {
    _start => sub {
      $poe_kernel->sig(ALRM => 'diediedie' => 'a lot');
      $zpub->start( $addr );
      $zsub->start( $addr );
      $poe_kernel->post( $zsub->session_id, 'subscribe' );
      $poe_kernel->post( $zpub->session_id, 'subscribe' );
    },

    zeromq_publishing_on => sub {
      $got->{'got publishing_on'} = 1;
      $zpub->timer( '0.2' => sub {
        $zpub->publish('hello listeners!');
        $zpub->timer( '0.2' => $_[STATE] );
      });
    },

    zeromq_subscribed_to => sub {
      $got->{'got subscribed_to'} = 1;
    },

    zeromq_received => sub {
      $got->{'received published'}++;
      $got->{'published data looks ok'}++
        if $_[ARG0] eq 'hello listeners!';
      if ($got->{'received published'} == 5) {
        $_[KERNEL]->yield( 'diediedie' );
      }
    },

    diediedie => sub {
      $_[KERNEL]->alarm_remove_all;
      fail "Timed out" if $_[ARG0];
      $zpub->stop;
      $zsub->stop;
    },
  }
);

$poe_kernel->run;
POEx::ZMQ3::Context->term;
is_deeply $got, $expected, 'pub/sub interaction ok';

done_testing;
