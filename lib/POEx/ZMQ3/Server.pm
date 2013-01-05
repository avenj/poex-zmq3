package POEx::ZMQ3::Server;

## FIXME repackage this into a ZMQ3::Role::Server ?
##  + Role::Server::Pub, Role::Server::Rep ?
## FIXME single-socket, hide $alias ?
##  - require a server type?
##    translate to constant for ->create_zmq_socket

use Carp;
use strictures 1;

use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';

use Storable 'nfreeze', 'thaw';

use Moo;
use namespace::clean;

with 'POEx::ZMQ3::Role::ZMQSockets';
with 'MooX::Role::POE::Emitter';

has context => (
  ## Should be shared between sessions, if possible
  lazy    => 1,
  is      => 'ro',
  default => sub { zmq_init },
);

has serializer => (
  is      => 'ro',
  writer  => 'set_serializer',
  default => sub {
    return sub { nfreeze($_[0]) }
  },
);

has deserializer => (
  is      => 'ro',
  writer  => 'set_deserializer',
  default => sub {
    return sub { thaw($_[0]) }
  },
);

sub start {
  my ($self) = @_;
  
  $self->set_event_prefix( 'zmq_' )
    unless $self->has_event_prefix;

  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_stop_emitter;
}

sub send {
  my ($self, $alias, $data) = @_;
  $self->process( 'send', $alias, $data );
  my $frozen = $self->serializer->($data);
  $self->write_zmq_socket( $alias, $data );
}

sub zmq_message_ready {
  my ($self, $alias, $zmsg, $data) = @_;
  my $thawed = $self->deserializer->($data);
  $self->emit( 'recv', $alias, $thawed );
}

sub zmq_socket_cleared {
  my ($self, $alias) = @_;
  ## FIXME
}

1;
