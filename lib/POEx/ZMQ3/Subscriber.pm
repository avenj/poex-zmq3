package POEx::ZMQ3::Role::Subscriber;

use Carp;
use Moo;

use ZMQ::Constants 'ZMQ_SUB';


use namespace::clean;


with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';


sub start {
  my ($self, @targets) = @_;
  $self->_start_emitter;

  $self->create_zmq_socket( 'sub', ZMQ_SUB );
  for my $target (@endpoints) {
    $self->add_target_endpoint( 'sub', $target );
    $self->emit( 'subscribed_to', $target );
  }

  $self
}

sub stop {
  my ($self) = @_;
  $self->emit( 'stopped' );
  $self->clear_zmq_socket('sub');
  $self->_stop_emitter;
}

sub zmq_message_ready {
  my ($self, $alias, $zmsg, $data) = @_;
  $self->emit( 'recv', $data )
}

1;
