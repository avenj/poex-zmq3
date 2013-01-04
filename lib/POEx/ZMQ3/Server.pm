package POEx::ZMQ3::Server;

use Carp;
use strictures 1;

use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';

use Moo;
use namespace::clean;

with 'POEx::ZMQ3::Role::ZMQSockets';

has context => (
  ## Should be shared between sessions, if possible
  lazy    => 1,
  is      => 'ro',
  default => sub { zmq_init },
);

sub zmq_message_ready {
  my ($self, $alias, $zmsg) = @_;
  ## FIXME
}

sub zmq_socket_cleared {
  my ($self, $alias) = @_;
  ## FIXME
}

1;
