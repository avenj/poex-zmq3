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
  'received published'      => 100,
  'published data looks ok' => 100,
};

POE::Session->create(
  inline_states => {
    _start => sub {
      $zpub->start( $addr );
      $zsub->start( $addr );
      $poe_kernel->post( $zpub->session_id, 'subscribe' );
      $poe_kernel->post( $zsub->session_id, 'subscribe' );
      $poe_kernel->delay( diediedie => 10 );
    },

    zeromq_publishing_on => sub {
      $got->{'got publishing_on'} = 1;
      $zpub->publish(
        'data from ze stream'
      ) for 1 .. 100;
    },

    zeromq_subscribed_to => sub {
      $got->{'got subscribed_to'} = 1;
    },

    zeromq_recv => sub {
      $got->{'received published'}++;
      $got->{'published data looks ok'}++
        if $_[ARG0] eq 'data from ze stream';
      if ($got->{'received published'} == 100) {
        $_[KERNEL]->yield( 'diediedie' );
      }
    },

    diediedie => sub {
      $_[KERNEL]->alarm_remove_all;
      $zpub->stop;
      $zsub->stop;
    },
  }
);

$poe_kernel->run;

is_deeply $got, $expected, 'pub/sub interaction ok';

done_testing;
