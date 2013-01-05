package POEx::ZMQ3::Server::Publisher;

use Carp;
use Moo;

use ZMQ::Constants 'ZMQ_PUB';


use namespace::clean;


with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';


sub start {
  my ($self, @endpoints) = @_;
  $self->_start_emitter;

  $self->create_zmq_socket( 'pub', ZMQ_PUB );
  for my $endpoint (@endpoints) {
    $self->add_endpoint('pub', $endpoint);
    $self->emit( 'publishing_on', $endpoint );
  }

  $self
}

sub stop {
  my ($self) = @_;
  $self->emit( 'stopped' );
  $self->clear_zmq_socket('pub');
  $self->_stop_emitter;
}

sub publish {
  my ($self, $data) = @_;
  $self->write_zmq_socket( 'pub', $data );
}

sub zmq_message_ready {
  ## A Publisher is one-way.
}

1;
