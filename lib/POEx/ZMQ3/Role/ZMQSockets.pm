package POEx::ZMQ3::Role::ZMQSockets;

use Carp;
use Moo::Role;
use strictures 1;

use POE;

use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';


use namespace::clean;

requires qw/
  zmq_message_ready
  context
/;

has '_zmqsockets' => (
  ## HashRef mapping aliases to ZMQ sockets
  lazy  => 1,
  is    => 'ro',
  isa   => sub {
    ref $_[0] eq 'HASH' or confess "$_[0] is not a HASH"
  },
  default => sub { +{} },
);

has '_zsock_sess_id' => (
  lazy    => 1,
  is      => 'ro',
  writer  => '_set_zsock_sess_id',
  default => sub { undef },
);


sub _create_zmq_socket_sess {
  my ($self) = @_;

  ## Spawn a Session to manage our ZMQ sockets, unless we have one.

  my $maybe_id = $self->_zsock_sess_id;
  return $maybe_id if $maybe_id
    and $poe_kernel->alias_resolve($maybe_id);

  my $sess = POE::Session->create(
    object_states => [
      $self => {
        _start      => '_start',
        zsock_ready => '_zsock_ready',
      },
    ],
  );

  my $id = $sess->ID;
  $self->_set_zsock_sess_id($id);
  $id
}

sub _start {}


sub create_zmq_socket {
  my ($self, $alias, $type) = @_;
  confess "Expected an alias and ZMQ::Constants socket type constant"
    unless defined $alias and defined $type;

  $self->_create_zmq_socket_sess;

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";

  $self->_zmqsockets->{$alias} = $zsock;
  $poe_kernel->select_read( $zsock,
    'zsock_ready',
    $alias
  );

  ## FIXME should we be trying an initial read ?

  $zsock
}

sub bind_zmq_socket {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpoint;
  
  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot bind_zmq_socket, no such alias $alias";

  unless ( zmq_bind($zsock, $endpoint) ) {
    confess "zmq_bind failed: $!"
  }

  $self
}

sub clear_zmq_socket {
  my ($self, $alias) = @_;

  my $zsock = $self->get_zmq_socket($alias);
  unless ($zsock) {
    carp "Cannot clear_zmq_socket, no such alias $alias";
    return
  }

  ## FIXME zmq_close before or after ?
  $poe_kernel->select_read($zsock);

  ## FIXME not required but document:
  $self->zmq_socket_cleared($alias) if $self->can('zmq_socket_cleared');

  delete $self->_zmqsockets->{$alias}
}

sub clear_all_zmq_sockets {
  my ($self) = @_;
  for my $alias (keys %{ $self->_zmqsockets }) {
    $self->clear_zmq_socket($alias);
  }
}

sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  $self->_zmqsockets->{$alias}
}

sub write_zmq_socket {
  my ($self, $alias, $data) = @_;
  my $zsock = $self->get_zmq_socket($alias);
  zmq_send( $zsock, zmq_msg_data($data) )
}


### POE
sub _zsock_ready {
  my ($kernel, $self)         = @_[KERNEL, OBJECT];
  my ($zsock, $mode, $alias) = @_[ARG0 .. $#_];

  ## Dispatch to consumer's handler.
  if (my $msg = zmq_recvmsg( $zsock, ZMQ_RCVMORE )) {
    $self->zmq_message_ready( $alias, $msg );
  }

}



1;
