package POEx::ZMQ3::Server::Publisher;

use Moo;

with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';


sub start {
  my ($self, @endpoints) = @_;
  $self->_start_emitter;

  for my $endpoint (@endpoints) {
    $self->add_endpoint('pub', $endpoint)
  }

  $self
}

sub stop {
  my ($self) = @_;
  $self->clear_all_zmq_sockets;
  $self->_stop_emitter;
}

sub publish {

}

1;
