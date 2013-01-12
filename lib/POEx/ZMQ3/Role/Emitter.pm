package POEx::ZMQ3::Role::Emitter;

use Carp;
use POE;
use Moo::Role;

use namespace::clean;

use POEx::ZMQ3::Sockets;
with 'MooX::Role::POE::Emitter';


requires 'start', 'stop';

has defined_states => (
  is      => 'ro',
  isa     => sub { 
    $_[0] and ref $_[0] eq 'ARRAY'
      or confess "defined_states should be an ARRAY"
  },
  builder => 'build_defined_states',
);
sub build_defined_states { [$_[0] => ['emitter_started'] ] }

has zmq => (
  lazy    => 1,
  is      => 'ro',
  default => sub { POEx::ZMQ3::Sockets->new },
);

has _zmq_binds => (
  is      => 'ro',
  default => sub { +{} }
);

has _zmq_connects => (
  is      => 'ro',
  default => sub { +{} },
);

sub add_bind {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpoint;
  $self->zmq->bind( $alias, $endpoint );
  $self->_zmq_binds->{$alias}->{$endpoint} = 1;
}

sub list_binds {
  my ($self, $alias) = @_;
  defined $alias ? keys %{ $self->_zmq_binds->{$alias} }
    : keys %{ $self->_zmq_binds }
}

sub add_connect {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpoint;
  $self->zmq->connect( $alias, $endpoint );
  $self->_zmq_connects->{$alias}->{$endpoint} = 1
}

sub list_connects {
  my ($self, $alias) = @_;
  defined $alias ? keys %{ $self->_zmq_connects->{$alias} }
    : keys %{ $self->_zmq_connects }
}

sub close_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  $self->zmq->close($alias);
  delete $self->_zmq_binds->{$alias};
  delete $self->_zmq_connects->{$alias};
}

after stop => sub {
  my ($self) = @_;
  delete $self->_zmq_binds->{$_} for keys %{ $self->_zmq_binds };
  delete $self->_zmq_connects->{$_} for keys %{ $self->_zmq_connects };
};

around _start_emitter => sub {
  my ($orig, $self) = splice @_, 0, 2;
  $self->set_event_prefix( 'zeromq_' ) unless $self->has_event_prefix;
  $self->set_pluggable_type_prefixes(+{
    PROCESS => 'P_Zmq',
    NOTIFY  => 'Zmq',
  }) unless $self->has_pluggable_type_prefixes;

  $self->set_object_states([
    @{ $self->defined_states } ,
    ( $self->has_object_states ? @{ $self->object_states } : () )
  ]);

  $self->$orig(@_);
};

sub _stop_emitter { shift->_shutdown_emitter(@_) }


1;

=pod

=head1 NAME

POEx::ZMQ3::Role::Emitter - Event emitter for POEx::ZMQ3::Sockets

=head1 SYNOPSIS

Primarily used internally; the following public methods are provided to
consumers:

  $component->add_bind( $alias, $endpoint );
  $component->add_connect( $alias, $endpoint );

  my @bound = $component->list_binds;
  my @connects = $component->list_connects;

  $component->close_socket( $alias );

  my $backend = $component->zmq;

=head1 DESCRIPTION

This is a small wrapper for L<MooX::Role::POE::Emitter>, providing some 
default attributes and sane defaults for a L<POEx::ZMQ3::Sockets>-based Emitter:

  The Emitter's event_prefix is 'zeromq_'
  'PROCESS' type events (->process) have the Pluggable prefix 'P_Zmq'
  'NOTIFY'  type events (->emit) have the Pluggable prefix 'Zmq'

A L<POEx::ZMQ3::Sockets> instance is automatically created if not provided;
see L</zmq>.

Some frontend methods for managing connections on a socket are provided. See
below.

=head2 Methods

=head3 zmq

Takes no arguments.

Returns the current L<POEx::ZMQ3::Sockets> instance.

=head3 add_bind

Takes a L<POEx::ZMQ3::Sockets> socket alias and an endpoint to bind.

=head3 list_binds

Takes an optional socket alias.

Returns a list of currently-tracked bound endpoints for the socket.

If no alias is specified, returns all currently-tracked aliases with bound
endpoints.

=head3 add_connect

Takes a socket alias and an endpoint to connect to.

=head3 list_connects

Takes the same arguments as L</list_binds>, but lists connect-type
endpoints instead.

=head3 close_socket

Takes a socket alias.

Closes and stops tracking the specified socket.

(This happens automatically when 'stop' is called.)

=head2 Consumers

A consumer session should override B<build_defined_states> to return an ARRAY
suitable for feeding to L<MooX::Role::POE::Emitter/object_states>:

  sub build_defined_states {
    my ($self) = @_;
    [
      $self => [ qw/
        emitter_started
        zmqsock_recv
      / ],
    ]
  }

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
