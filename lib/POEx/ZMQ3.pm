package POEx::ZMQ3;

use Carp;
use ZMQ::Constants ':all';
use ZMQ::LibZMQ3;

use Moo;
use POE qw/
  Filter::Reference
/;

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


has filter => (
  ## FIXME optional serialize/deserialize methods
  ##  instead of a POE::Filter ... ?
  ##  Filter::Reference is probably too much overhead
  ##  we already have data sizing via zmq
  lazy      => 1,
  is        => 'ro',
  writer    => 'set_filter',
  clearer   => 'clear_filter',
  predicate => 'has_filter',
  default   => sub { POE::Filter::Reference->new }
);


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


## FIXME add a Storable serialize role that overrides?
##  here ->
 ##   sub serialize_via {}
##  subclass ->
 ##    package MyProject::MQ;
 ##    extends 'POEx::ZMQ3';
 ##    with 'POEx::ZMQ3::Speaking::Storable';
sub serialize_via {
  my ($self, $data) = @_;
  $data
}

sub deserialize_via {
  my ($self, $data) = @_;
  $data
}


1;
