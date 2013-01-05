package POEx::ZMQ3::Role::Endpoints;

use Moo::Role;

with 'POEx::ZM3::Role::Sockets';

has '_zmq_endpoints' => (
  is => 'ro',
  default => sub { {} },
);

sub add_endpoint {
  my ($self, $alias, $
}

1;
