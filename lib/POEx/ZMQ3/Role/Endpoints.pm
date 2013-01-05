package POEx::ZMQ3::Role::Endpoints;

use Carp;
use Moo::Role;

with 'POEx::ZMQ3::Role::Sockets';

has '_zmq_endpoints' => (
  is => 'ro',
  default => sub { +{} },
);

has '_zmq_targets' => (
  is => 'ro',
  default => sub { +{} },
);


after clear_zmq_socket => sub {
  my ($self, $alias) = @_;
  
  for my $endpoint ($self->list_endpoints) {
    delete $self->_zmq_endpoints->{$endpoint}
      if $self->_zmq_endpoints->{$endpoint} eq $alias
  }

  for my $target ($self->list_target_endpoints) {
    delete $self->_zmq_targets->{$target}
      if $self->_zmq_targets->{$target} eq $alias
  }
};


sub add_endpoint {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint" unless $endpoint;
  $self->bind_zmq_socket( $alias, $endpoint );
  $self->_zmq_endpoints->{$endpoint} = $alias;
  $self
}

sub list_endpoints {
  my ($self) = @_;
  keys %{ $self->_zmq_endpoints }
}

sub add_target_endpoint {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint" unless $endpoint;
  $self->connect_zmq_socket( $alias, $endpoint );
  $self->_zmq_targets->{$endpoint} = $alias;
  $self
}

sub list_target_endpoints {
  my ($self) = @_;
  keys %{ $self->_zmq_targets }
}

1;


=pod

=head1 NAME

POEx::ZMQ3::Role::Endpoints - Add and track ZMQ targets and endpoints

=head1 SYNOPSIS

  ## Bind some endpoints:
  package MyZMQServer;
  use Moo;

  # Automatically consumes POEx::ZMQ3::Role::Sockets as well:
  with 'POEx::ZMQ3::Role::Endpoints';

  sub start {
    my ($self, @endpoints) = @_;
    $self->_start_emitter;
    $self->create_zmq_socket( $alias, ZMQ_PUB );

    ## Bind some endpoints:
    for my $endpoint (@endpoints) {
      $self->add_endpoint( $alias, $endpoint )
    }
  }

  ## Connect some targets:
  package MyZMQClient;
  . . .
  sub start {
    . . .
    ## Connect some targets:
    for my $target (@targets) {
      $self->add_target_endpoint( $alias, $target )
    }
  }

=head1 DESCRIPTION

A L<Moo::Role> that adds ZeroMQ endpoint management methods to
L<POEx::ZMQ3::Role::Sockets>.

=head2 add_endpoint

  $self->add_endpoint( $alias, $endpoint );

Adds and calls B<zmq_bind> for a specified endpoint.

=head2 list_endpoints

  my @endpoints = $self->list_endpoints;

List all currently known bound endpoints.

=head2 add_target_endpoint

  $self->add_target_endpoint( $alias, $target );

Adds and calls B<zmq_connect> for a specified target.

=head2 list_target_endpoints

  my @connected = $self->list_target_endpoints;

Lists all currently known target endpoints.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
