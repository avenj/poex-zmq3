package POEx::ZMQ3;

use Carp;
use ZMQ::Constants;
use ZMQ::LibZMQ3;

use Moo;
use POE;
with 'MooX::Role::POE::Emitter';

has _ctxt => (
  lazy      => 1,
  is        => 'ro',
  writer    => '_set_ctxt',
  builder   => '_build_ctxt',
  predicate => '_has_ctxt',
);
sub _build_ctxt {  zmq_init  }

sub start {
  my ($self) = @_;
  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_stop_emitter;
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
