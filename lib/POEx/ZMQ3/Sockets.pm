package POEx::ZMQ3::Sockets;

use 5.10.1;
use Carp;
use Moo;
use POE;
require POSIX;

use ZMQ::LibZMQ3;
## FIXME pull specific constants
use ZMQ::Constants ':all';


with 'MooX::Role::POE::Emitter';
use MooX::Role::Pluggable::Constants;


use MooX::Struct -rw,
  ZMQSocket => [ qw/
    +is_closing
    zsock
    handle
    fd
    @buffer
  / ],
  BufferItem => [ qw/
    data
    flags
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
      zsock_ready   => '_zsock_ready',
      zsock_watch   => '_zsock_watch',
      zsock_unwatch => '_zsock_unwatch',
      zsock_write   => '_zsock_write',
      
      create      => '_zpub_create',
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


sub start {
  my ($self) = @_;
  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_zmq_clear_all;
  $self->yield( 'shutdown_emitter' );
}

sub emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

}

sub emitter_stopped {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_zmq_clear_all;
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

sub create {
  my $self = shift;
  $self->call( 'create', @_ )
}

sub _zpub_create {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_zmq_create_sock( @_[ARG0 .. $#_] )
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

  my $ref = $self->_zmq_sockets->{$alias}
    || confess "Cannot queue write; no such alias $alias";
  my $item = BufferItem->new(data  => $data, flags => $flags);
  $ref->buffer ? push(@{ $ref->buffer }, $item) : $ref->buffer([ $item ]);
  $self->call( 'zsock_write', $alias );
}

sub _zsock_write {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $struct = $self->_zmq_sockets->{$alias}
    || confess "Cannot execute write; no such alias $alias";
  return unless $struct->buffer and @{ $struct->buffer };

  my $next  = $struct->buffer->[0];
  my $data  = $next->data;
  my $flags = $next->flags;
  unless (ref $data) {
    $data = zmq_msg_init_data($data)
  }

  my $rc;
  if ( $rc = zmq_msg_send( $data, $struct->zsock, ($flags ? $flags : ()) ) 
      && ($rc//0) == -1 ) {

    unless ($rc == POSIX::EAGAIN || $rc == POSIX::EINTR) {
      confess "zmq_msg_send failed; $!";
    }
    $self->yield( 'zsock_write', $alias )
  } else {
    ## Successfully queued on socket.
    shift @{ $struct->buffer }
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
  my (undef, $mode, $alias) = @_[ARG0 .. $#_];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to read socket '$alias' but no such socket struct";
    return
  }

  if ($struct->is_closing) {
    warn "Socket '$alias' ready but closing"
      if $ENV{POEX_ZMQ_DEBUG};
    return
  }

  warn "I'm in _ready ($mode) for $alias"; #DEBUG

  ## FIXME better err handling esp. zmq_msg_data ?
#  my $msg = zmq_msg_init;
#  warn 'DEBUG init msg';
#  ## FIXME
#  ##  use ZMQ_DONTWAIT ?
#  my $parts_count = 1;
#  RECV: while (1) {
#    if ( zmq_msg_recv($msg, $struct->zsock, ZMQ_DONTWAIT) == -1 ) {
#      return if $! == POSIX::EAGAIN;
#      confess "zmq_msg_recv failed; $!"
#      return
#    }
#
#    warn 'DEBUG recv msg';
#
#    unless ( zmq_getsockopt($struct->zsock, ZMQ_RCVMORE) ) {
#      warn 'DEBUG no rcvmore';
#      ## No more message parts.
#      $self->emit( recv => 
#        $alias, 
#        $msg, 
#        zmq_msg_data($msg), 
#        $parts_count 
#      );
#      last RECV
#    }
#    warn 'DEBUG more to recv';
#    ## More parts to follow.
#    $parts_count++;
#  }

  while (my $msg = zmq_recvmsg( $struct->zsock, ZMQ_RCVMORE )) {
    warn "I'm recving"; #DEBUG
    $self->emit( recv => $alias, $msg, zmq_msg_data($msg) )
  }

  warn "I'm done with _ready";#DEBUG

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

  open(my $fh, '+<&=', $fd ) or confess "failed fdopen: $!";

  $self->_zmq_sockets->{$alias} = ZMQSocket->new(
    zsock  => $zsock,
    handle => $fh,
    fd     => $fd,
  );

  ## FIXME adjust IPV4ONLY if we have ->use_ipv6 or so?
  $self->set_zmq_sockopt($alias, ZMQ_LINGER, 0);

  $self->call( zsock_watch => $alias )
}

sub _zsock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to watch $alias but no such socket?";
    return
  }

  $kernel->select( $struct->handle,
    'zsock_ready',
    undef, undef,
    $alias
  );

  1
}

sub _zsock_unwatch {
  my ($kernel, $self, $alias) = @_[KERNEL, OBJECT, ARG0];
  my $struct = delete $self->_zmq_sockets->{$alias};
  $kernel->select( $struct->handle )
}

sub _zmq_clear_sock {
  my ($self, $alias) = @_;

  my $zsock = $self->get_zmq_socket($alias);

  zmq_close($zsock);
  $self->_zmq_sockets->{$alias}->is_closing(1);
  
  $self->yield( zsock_unwatch => $alias )
}

sub _zmq_clear_all {
  my ($self) = @_;
  $self->_zmq_clear_sock($_) for keys %{ $self->_zmq_sockets }
}

1;
