package POEx::ZMQ3::Sockets;

use 5.10.1;
use Carp;
use Moo;
use POE;


use ZMQ::LibZMQ3;
## FIXME pull specific constants
use ZMQ::Constants ':all';


with 'MooX::Role::POE::Emitter';
use MooX::Role::Pluggable::Constants;


use MooX::Struct -rw,
  ZMQSocket => [ qw/
    zsock
    handle
    fd
  / ],
;


require POEx::ZMQ3::Context;
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
      zsock_watch => '_zsock_watch',
      
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


sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  my $struct = $self->_zmq_sockets->{$alias} || return;
  $struct->zsock
}

sub set_zmq_sockopt {
  my ($self, $alias) = splice @_, 0, 2;
  confess "Expected an alias and params to feed zmq_setsockopt"
    unless @_;

  my $zsock = $self->get_zmq_socket($alias)
    || confess "Cannot set_zmq_sockopt; no such alias $alias";
  
  if ( zmq_setsockopt($zsock, @_) == -1 ) {
    confess "zmq_setsockopt failed; $!"
  }

  $self
}


sub bind {
  my $self = shift;
  $self->yield( 'bind', @_ )
}

sub _zpub_bind {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $endpt) = @_[ARG0 .. $#_];
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpt;

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot bind; no such alias $alias";
  if ( zmq_bind($zsock, $endpt) ) {
    confess "zmq_bind failed; $!"
  }
  1
}


sub connect {
  my $self = shift;
  $self->yield( 'connect', @_ )
}

sub _zpub_connect {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $endpt) = @_[ARG0 .. $#_];
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpt;
  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot connect; no such alias $alias";
  if ( zmq_connect($zsock, $endpt) ) {
    confess "zmq_connect failed; $!"
  }
  1
}


sub write {
  my $self = shift;
  $self->yield( 'write', @_ )
}

sub _zpub_write {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $data, $flags) = @_[ARG0 .. $#_];

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot write; no such alias $alias";

  ## FIXME ZMQ_DONTWAIT and check for EAGAIN ?
  if ( zmq_msg_send($data, $zsock, ($flags ? $flags : () ) == -1) ) {
    confess "zmq_msg_send failed; $!"
  }
  1
}

sub close {
  my $self = shift;
  $self->yield( 'close', @_ )
}

sub _zpub_close {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  $self->_zmq_clear_sock($alias)
}

## Workers.

sub _zsock_ready {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG2];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to read socket '$alias' but no such socket struct";
    return
  }

  ## FIXME better err handling esp. zmq_msg_data ?
  my $msg = zmq_msg_init;
  ## FIXME
  ##  use ZMQ_DONTWAIT ?
  my $parts_count = 1;
  RECV: while (1) {
    if ( zmq_msg_recv($msg, $struct->zsock) == -1 ) {
      confess "zmq_msg_recv failed; $!"
    }

    unless ( zmq_getsockopt($struct->zsock, ZMQ_RCVMORE) ) {
      ## No more message parts.
      $self->emit( recv => 
        $alias, 
        $msg, 
        zmq_msg_data($msg), 
        $parts_count 
      )
      last RECV
    }
    ## More parts to follow.
    $parts_count++;
  }

  1  
}

sub _zmq_create_sock {
  my ($self, $alias, $type) = @_; 
  confess "Expected an alias and sock type"
    unless defined $alias and defined $type;

  $type = $stringy_types{$type} if exists $stringy_types{$type};

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";
  my $fd = zmq_getsockopt( $zsock, ZMQ_FD )
    or confess "zmq_getsockopt failed: $!";

  open(my $fh, '<&=', $fd ) or confess "failed fdopen: $!";

  $self->_zmq_sockets->{$alias} = ZMQSocket->new(
    zsock  => $zsock,
    handle => $fh,
    fd     => $fd,
  );

  $poe_kernel->call( $self->session_id, zsock_watch => $alias );

  $alias
}

sub _zsock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to watch $alias but no such socket?";
    return
  }

  $kernel->select_read( $struct->handle,
    'zsock_ready',
    $alias
  );
  1
}

sub _zmq_clear_sock {
  ## FIXME
}

1;
