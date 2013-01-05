package POEx::ZMQ3::Role::ZMQSockets;

use Carp;
use Moo::Role;
use strictures 1;

use IO::File;

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
        _start         => '_zsock_start',
        zsock_ready    => '_zsock_ready',
        zsock_handle_socket => '_zsock_handle_socket',
        zsock_giveup_socket => '_zsock_giveup_socket',
      },
    ],
  );

  my $id = $sess->ID;
  $self->_set_zsock_sess_id($id);
  $id
}

sub create_zmq_socket {
  my ($self, $alias, $type) = @_;
  confess "Expected an alias and ZMQ::Constants socket type constant"
    unless defined $alias and defined $type;

  $self->_create_zmq_socket_sess;

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";
  my $fd = zmq_getsockopt( $zsock, ZMQ_FD )
    or confess "zmq_getsockopt failed: $!";
  my $fh = IO::File->new("<&=$fd")
    or confess "failed dup in socket creation: $!";
  $self->_zmqsockets->{$alias}->{zsock}  = $zsock;
  $self->_zmqsockets->{$alias}->{handle} = $fh;
  $self->_zmqsockets->{$alias}->{fd}     = $fd;

  $poe_kernel->call( $self->_zsock_sess_id, 
    'zsock_handle_socket',
    $alias
  );

  $zsock
}

sub bind_zmq_socket {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpoint;
  
  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot bind_zmq_socket, no such alias $alias";

  if ( zmq_bind($zsock, $endpoint) ) {
    confess "zmq_bind failed: $!"
  }

  ## FIXME should we try an initial read or will select do the right thing?

  $self
}

sub connect_zmq_socket {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and a target"
    unless defined $alias and defined $endpoint;

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot connect_zmq_socket, no such alias $alias";

  if ( zmq_connect($zsock, $endpoint) ) {
    confess "zmq_connect failed: $!"
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

  $poe_kernel->call( $self->_zsock_sess_id,
    'zsock_giveup_socket',
    $alias
  );

  delete $self->_zmqsockets->{$alias};
  zmq_close($zsock);
  undef $zsock;

  ## FIXME not required but document:
  $self->zmq_socket_cleared($alias) if $self->can('zmq_socket_cleared');
  
  $self
}

sub clear_all_zmq_sockets {
  my ($self) = @_;
  for my $alias (keys %{ $self->_zmqsockets }) {
    $self->clear_zmq_socket($alias);
  }
  $self
}

sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  $self->_zmqsockets->{$alias}->{zsock}
}

sub write_zmq_socket {
  my ($self, $alias, $data) = @_;
  my $zsock = $self->get_zmq_socket($alias);
  ## _sendmsg creates an appropriate obj if not given one:
  if ( zmq_sendmsg( $zsock, $data ) == -1 ) {
    confess "zmq_sendmsg failed: $!";
  }
  $self
}


### POE
sub _zsock_handle_socket {
  my ($kernel, $self)  = @_[KERNEL, OBJECT];
  my $alias  = $_[ARG0];
  my $ref    = $self->_zmqsockets->{$alias} || return;

  $kernel->select( $ref->{handle},
    'zsock_ready',
    undef,
    undef,
    $alias
  );

  ## See if anything was prebuffered.
  while (my $msg = zmq_recvmsg( $ref->{zsock}, ZMQ_RCVMORE )) {
    my $data = zmq_msg_data($msg);
    $self->zmq_message_ready( $alias, $msg, $data );
  }
}

sub _zsock_giveup_socket {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $ref   = $self->_zmqsockets->{$alias} || return;
  my $handle = $ref->{handle};
  $kernel->select( $handle );
}

sub _zsock_ready {
  my ($kernel, $self)         = @_[KERNEL, OBJECT];
  my ($handle, $mode, $alias)  = @_[ARG0 .. $#_];

  my $zsock = $self->get_zmq_socket($alias);

  ## Dispatch to consumer's handler.
  while (my $msg = zmq_recvmsg( $zsock, ZMQ_RCVMORE )) {
    my $data = zmq_msg_data($msg); 
    $self->zmq_message_ready( $alias, $msg, $data );
  }
}

sub _zsock_start { 1 }


1;
