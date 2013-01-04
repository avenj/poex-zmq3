package POEx::ZMQ3;

use Carp;
use ZMQ::Constants ':all';
use ZMQ::LibZMQ3;

use Moo;
use POE;

use POEx::ZMQ3::Connector;
use POEx::ZMQ3::Listener;

use namespace::clean;

with 'MooX::Role::POE::Emitter';

has _ctxt => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_ctxt',
  builder   => '_build_ctxt',
  predicate => '_has_ctxt',
);
## Should be rebuilt if you fork:
sub _build_ctxt {  zmq_init  }


has _listeners => (

);
sub _listener_create {
  my ($self) = shift;
  POEx::ZMQ3::Listener->new(
    emitter => $self,
    context => $self->_ctxt,
    @_
  )
}
sub _listener_add {

}
sub _listener_del {

}

has _connectors => (

);
sub _connector_create {
  my $self = shift;
  POEx::ZMQ3::Connector->new(
    emitter => $self,
    context => $self->_ctxt,
  )
}
sub _connector_add {

}
sub _connector_del {

}

sub start {
  my ($self) = @_;
  $self->set_event_prefix( 'zmq_' ) unless $self->has_event_prefix;
  $self->set_pluggable_type_prefixes(
    PROCESS => 'P',
    NOTIFY  => 'Zmq',
  ) unless $self->has_pluggable_type_prefixes;
  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_shutdown_emitter;
}

sub listen {
  ## FIXME spawn a server/listener
}

sub stop_listening {

}

sub connect {

}

sub disconnect {

}

sub send {

}

1;
