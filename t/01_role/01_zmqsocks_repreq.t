use Test::More;
use Test::TCP;
use strict; use warnings qw/FATAL all/;

use ZMQ::Constants ':all';
use ZMQ::LibZMQ3;
diag "Testing with libzeromq ".ZMQ::LibZMQ3::zmq_version;

use POE;

my $mcount = 2000;
my $expected = +{
  map {; $_ => $mcount } qw/
    message_ready
    correct_data
    client_message_ready
    client_correct_data
  /
};
my $got = {};

my $port = empty_port;

my $alarm_id;

{ package
    MyZMQServer;
  use strict; use warnings qw/FATAL all/;
  use Moo;
  use ZMQ::Constants ':all';

  with 'POEx::ZMQ3::Role::Sockets';

  sub start {
    my ($self) = @_;
    $self->create_zmq_socket( 'myServsock',
      ZMQ_REP
    );
    $self->bind_zmq_socket( 'myServsock', 'tcp://127.0.0.1:'.$port );
  }

  sub stop {
    my ($self) = @_;
    $self->clear_all_zmq_sockets;
  }

  sub zmq_message_ready {
    my ($self, $alias, $msg, $data) = @_;
    $got->{message_ready}++;
    $got->{correct_data}++ if $data eq 'this is not a message';
    $self->write_zmq_socket( 'myServsock', 'this is not a reply' );
  }
}

my $server = MyZMQServer->new;
pass "Server created";


{ package
    MyZMQClient;
  use strict; use warnings qw/FATAL all/;
  use Moo;
  use ZMQ::Constants ':all';

  with 'POEx::ZMQ3::Role::Sockets';

  sub start {
    my ($self) = @_;
    $self->create_zmq_socket( 'mysock',
      ZMQ_REQ
    );
    $self->connect_zmq_socket( 'mysock',
      'tcp://127.0.0.1:'.$port
    );
    $self->write_zmq_socket( 'mysock', 'this is not a message' );
  }

  sub stop {
    my ($self) = @_;
    $self->clear_all_zmq_sockets;
  }

  sub zmq_message_ready {
    my ($self, $alias, $msg, $data) = @_;
    $got->{client_message_ready}++;
    $got->{client_correct_data}++ if $data eq 'this is not a reply';
    if (($got->{client_message_ready}||=0) == $mcount) {
      $self->stop;
      $server->stop;
      return
    }
    $self->write_zmq_socket( 'mysock', 'this is not a message' );
  }
}

my $client = MyZMQClient->new;
pass "Client created";
alarm 10;
POE::Session->create(
  inline_states => {
    _start => sub {
      $server->start;
      $client->start;
      $_[KERNEL]->sig(ALRM => 'fail');
      pass "Session created";
    },
    fail => sub {
      $client->stop; $server->stop;
      fail "Timed out"
    },
  },
);

$poe_kernel->run;

is_deeply( $got, $expected, "REQ/REP exchanged $mcount messages" );

done_testing;
