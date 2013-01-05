use Test::More;
use Test::TCP;
use strict; use warnings qw/FATAL all/;

use ZMQ::Constants ':all';
use ZMQ::LibZMQ3;

my $ctxt = zmq_init;

use POE;

my $expected = {
  message_ready => 100,
  correct_data  => 100,
  client_message_ready => 100,
  client_correct_data  => 100,
};
my $got = {};

my $port = empty_port;

{ package
    MyZMQServer;
  use strict; use warnings qw/FATAL all/;
  use Moo;
  use ZMQ::Constants ':all';

  sub context { $ctxt }
  
  with 'POEx::ZMQ3::Role::ZMQSockets';

  sub start {
    my ($self) = @_;
    $self->create_zmq_socket( 'myServsock',
      ZMQ_REP
    );
    warn "server create";
    $self->bind_zmq_socket( 'myServsock', 'tcp://127.0.0.1:'.$port );
    warn "create, bind";
  }

  sub stop {
    my ($self) = @_;
    $self->clear_all_zmq_sockets;
  }

  sub zmq_message_ready {
    my ($self, $alias, $msg, $data) = @_;
    warn "server message $data";
    $got->{message_ready}++;
    $got->{correct_data}++ if $data eq 'this is not a message';
    warn "writing back to client";
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

  sub context { $ctxt }

  with 'POEx::ZMQ3::Role::ZMQSockets';

  sub start {
    my ($self) = @_;
    $self->create_zmq_socket( 'mysock',
      ZMQ_REQ
    );
    warn "client create";
    $self->connect_zmq_socket( 'mysock',
      'tcp://127.0.0.1:'.$port
    );
    warn "client connect";
    $self->write_zmq_socket( 'mysock', 'this is not a message' );
    warn "client create, connect, write";
  }

  sub stop {
    my ($self) = @_;
    $self->clear_all_zmq_sockets;
  }

  sub zmq_message_ready {
    my ($self, $alias, $msg, $data) = @_;
    warn "client message $data";
    if (($got->{client_message_ready}||=0) == 100) {
      warn "stopping";
      $self->stop;
      $server->stop;
    }
    $got->{client_message_ready}++;
    $got->{client_correct_data}++ if $data eq 'this is not a reply';
    $self->write_zmq_socket( 'mysock', 'this is not a message' );
  }
}

my $client = MyZMQClient->new;
pass "Client created";

POE::Session->create(
  inline_states => {
    _start => sub {
      $server->start;
      $client->start;
      pass "Session created";
    },
  },
);
## FIXME timer to shut these down if they take too long?

$poe_kernel->run;

is_deeply( $got, $expected );

done_testing;
