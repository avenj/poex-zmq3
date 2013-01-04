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
  _ctxt
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

sub create_zmq_socket {
  my ($self, $alias, $type) = @_;
  confess "Expected an alias and ZMQ::Constants socket type constant"
    unless defined $alias and defined $type;

  my $zsock = zmq_socket( $self->_ctxt, $type )
    or confess "zmq_socket failed: $!";

  $self->_zmqsockets->{$alias} = $zsock;
  ## FIXME set up a POE select() for this zsock
  ##  pass $alias with extra args
  $zsock
}

sub clear_zmq_socket {
  my ($self, $alias) = @_;
  my $zsock = $self->get_zmq_socket($alias);
  unless ($zsock) {
    carp "Cannot clear_zmq_socket, no such alias $zsock";
    return
  }

  ## FIXME unselect this zsock
  ##  issue event

  delete $self->_zmqsockets->{$alias}
}

sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  $self->_zmqsockets->{$alias}
}

sub write_zmq_socket {
  my ($self, $alias, $data) = @_;
  ## FIXME
  ##  serialize if we ->can()
  ##  zmq_send( $zsock, zmq_msg_data($data) )
}


after BUILD => sub {
  my ($self) = @_;
  ## FIXME set up a POE::Session to manage our sockets
  ## Call a POE::Kernel->select()
};


sub _zmqsock_read_ready {
  ## FIXME call a zmq_recvmsg
  ##  deserialize if we ->can()
  ##  Dispatch to ->zmq_message_ready()
}

sub _zmqsock_write_ready {
  ## FIXME do we need this?
  ## FIXME should be able to just zmq_send whenever anyway
}


1;
