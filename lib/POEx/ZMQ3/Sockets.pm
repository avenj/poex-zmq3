package POEx::ZMQ3::Sockets;

use 5.10.1;
use Carp;
use Moo;
use POE;

use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';

use MooX::Role::Pluggable::Constants;
with 'MooX::Role::POE::Emitter';


use MooX::Struct -rw,
  ZMQSocket => [ qw/
    +is_closing
  / ],
;


use POEx::ZMQ3::Context;
has context => (
  is      => 'ro',
  default => sub { POEx::ZMQ3::Context->new },
);

has _zmq_sockets => (
  is      => 'ro',
  default => sub { +{} },
);

my %stringy_types = (
  REQ     => ZMQ_REQ,
  REP     => ZMQ_REP,
  DEALER  => ZMQ_DEALER,
  ROUTER  => ZMQ_ROUTER,

  PUB     => ZMQ_PUB,
  SUB     => ZMQ_SUB,
  XPUB    => ZMQ_XPUB,
  XSUB    => ZMQ_XSUB,
  PUSH    => ZMQ_PUSH,
  PULL    => ZMQ_PULL,

  PAIR => ZMQ_PAIR,
);

sub BUILD {
  my ($self) = @_;

  $self->set_event_prefix( 'zmqsock_' )
    unless $self->has_event_prefix;

  $self->set_register_prefix( 'ZMQSock_' )
    unless $self->has_register_prefix;

  $self->set_shutdown_signal( 'SHUTDOWN_ZMQSOCKETS' )
    unless $self->has_shutdown_signal;

  $self->set_object_states([
    $self => {
      zsock_ready => '_zsock_ready',
      
      bind        => '_zpub_bind',
      connect     => '_zpub_connect',
      write       => '_zpub_write',
      close       => '_zpub_close',
    },
    $self => [
      'emitter_started',
      'emitter_stopped',
    ],
  ]);
}


sub spawn {
  my ($self) = @_;
  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_shutdown_emitter;
}

sub emitter_started {

}

sub emitter_stopped {

}


sub bind {

}

sub _zpub_bind {

}


sub connect {

}

sub _zpub_connect {

}


sub write {

}

sub _zpub_write {

}

sub close {

}

sub _zpub_close {

}

## Workers.

sub _zsock_ready {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

}

sub _zmq_create_sock {
  
}

sub _zmq_clear_sock {
}

1;
