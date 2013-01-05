package POEx::ZMQ3::Role::ZMQSockets;
our $VERSION = '0.00_01';

use Carp;
use Moo::Role;
use strictures 1;

use IO::File;

use POE;

use Scalar::Util 'weaken';

use ZMQ::LibZMQ3;
use ZMQ::Constants ':all';

use namespace::clean;

requires 'zmq_message_ready';

has 'context' => (
  ## These can/should be shared.
  ## ... so long as you reset on fork
  lazy    => 1,
  is      => 'ro',
  writer  => '_set_context',
  default => sub {
    zmq_init or confess "zmq_init failed: $!" 
  },
);

has '_zmq_sockets' => (
  ## HashRef mapping aliases to ZMQ sockets
  lazy  => 1,
  is    => 'ro',
  isa   => sub {
    ref $_[0] eq 'HASH' or confess "$_[0] is not a HASH"
  },
  default => sub { +{} },
);

has '_zmq_zsock_sess' => (
  lazy    => 1,
  is      => 'ro',
  writer  => '_set_zmq_zsock_sess',
  default => sub { undef },
);


sub _create_zmq_socket_sess {
  my ($self) = @_;

  ## Spawn a Session to manage our ZMQ sockets, unless we have one.

  my $maybe_id = $self->_zmq_zsock_sess;
  return $maybe_id if $maybe_id
    and $poe_kernel->alias_resolve($maybe_id);

  my $sess = POE::Session->create(
    object_states => [
      $self => {
        _start         => '_zsock_start',
        zsock_ready    => '_zsock_ready',
        zsock_handle_socket => '_zsock_handle_socket',
        zsock_giveup_socket => '_zsock_giveup_socket',
      },
    ],
  );

  my $id = $sess->ID;
  $self->_set_zmq_zsock_sess($id);
  $id
}

sub create_zmq_socket {
  my ($self, $alias, $type) = @_;
  confess "Expected an alias and ZMQ::Constants socket type constant"
    unless defined $alias and defined $type;

  my $sess_id = $self->_create_zmq_socket_sess;

  confess "Alias $alias exists; clear it first"
    if $self->get_zmq_socket($alias);

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";
  my $fd = zmq_getsockopt( $zsock, ZMQ_FD )
    or confess "zmq_getsockopt failed: $!";
  my $fh = IO::File->new("<&=$fd")
    or confess "failed dup in socket creation: $!";
  $self->_zmq_sockets->{$alias} = +{
    zsock  => $zsock,
    handle => $fh,
    fd     => $fd,
  };

  $poe_kernel->call( $sess_id,
    'zsock_handle_socket',
    $alias
  );

  $zsock
}

sub bind_zmq_socket {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpoint;
  
  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot bind_zmq_socket, no such alias $alias";

  if ( zmq_bind($zsock, $endpoint) ) {
    confess "zmq_bind failed: $!"
  }

  ## FIXME should we try an initial read or will select do the right thing?

  $self
}

sub connect_zmq_socket {
  my ($self, $alias, $endpoint) = @_;
  confess "Expected an alias and a target"
    unless defined $alias and defined $endpoint;

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot connect_zmq_socket, no such alias $alias";

  if ( zmq_connect($zsock, $endpoint) ) {
    confess "zmq_connect failed: $!"
  }

  $self
}

sub clear_zmq_socket {
  my ($self, $alias) = @_;

  my $zsock = $self->get_zmq_socket($alias);
  unless ($zsock) {
    carp "Cannot clear_zmq_socket, no such alias $alias";
    return
  }

  zmq_close($zsock);
  undef $zsock;

  $poe_kernel->call( $self->_zmq_zsock_sess,
    'zsock_giveup_socket',
    $alias
  );

  delete $self->_zmq_sockets->{$alias};

  ## FIXME not required but document:
  $self->zmq_socket_cleared($alias) if $self->can('zmq_socket_cleared');
  
  $self
}

sub clear_all_zmq_sockets {
  my ($self) = @_;
  for my $alias (keys %{ $self->_zmq_sockets }) {
    $self->clear_zmq_socket($alias);
  }
  $self
}

sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  $self->_zmq_sockets->{$alias}->{zsock}
}

sub write_zmq_socket {
  my ($self, $alias, $data) = @_;
  confess "Expected an alias and data"
    unless defined $alias and defined $data;

  my $zsock = $self->get_zmq_socket($alias);
  unless ($zsock) {
    carp "Cannot write_zmq_socket; no such alias $alias";
    return
  }
  ## _sendmsg creates an appropriate obj if not given one:
  if ( zmq_sendmsg( $zsock, $data ) == -1 ) {
    confess "zmq_sendmsg failed: $!";
  }
  $self
}


### POE
sub _zsock_handle_socket {
  my ($kernel, $self)  = @_[KERNEL, OBJECT];
  my $alias  = $_[ARG0];
  my $ref    = $self->_zmq_sockets->{$alias} || return;

  $kernel->select( $ref->{handle},
    'zsock_ready',
    undef,
    undef,
    $alias
  );

  ## See if anything was prebuffered.
  while (my $msg = zmq_recvmsg( $ref->{zsock}, ZMQ_RCVMORE )) {
    my $data = zmq_msg_data($msg);
    $self->zmq_message_ready( $alias, $msg, $data );
  }
}

sub _zsock_giveup_socket {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $ref   = $self->_zmq_sockets->{$alias} || return;
  my $handle = $ref->{handle};
  $kernel->select( $handle );
}

sub _zsock_ready {
  my ($kernel, $self)         = @_[KERNEL, OBJECT];
  my ($handle, $mode, $alias)  = @_[ARG0 .. $#_];

  my $zsock = $self->get_zmq_socket($alias) || return;

  ## Dispatch to consumer's handler.
  while (my $msg = zmq_recvmsg( $zsock, ZMQ_RCVMORE )) {
    my $data = zmq_msg_data($msg); 
    $self->zmq_message_ready( $alias, $msg, $data );
  }
}

sub _zsock_start { 1 }


1;

=pod

=head1 NAME

POEx::ZMQ3::Role::ZMQSockets - Add ZeroMQ sockets to a class

=head1 SYNOPSIS

  ## A 'REP' (reply) server that pongs mindlessly, given a ping.
  ## (Call ->start() from a POE-enabled class/app.)
  package MyZMQServer;
  use Moo;
  use ZMQ::Constants ':all';

  with 'POEx::ZMQ3::Role::ZMQSockets';

  sub start {
    my ($self) = @_;
    $self->create_zmq_socket( 'my_server', ZMQ_REP );
    $self->bind_zmq_socket( 'my_server', "tcp://127.0.0.1:$port" );
  }

  sub stop {
    my ($self) = @_;
    $self->clear_all_zmq_sockets;
  }

  sub zmq_message_ready {
    my ($self, $zsock_alias, $zmq_msg, $raw_data) = @_;
    $self->write_zmq_socket( $zsock_alias, "PONG!" )
      if $raw_data =~ /^PING/i;
  }

=head1 DESCRIPTION

A L<Moo::Role> giving its consuming class L<POE>-enabled asynchronous
B<ZeroMQ> sockets via L<ZMQ::LibZMQ3>.

See L<http://www.zeromq.org> for more about ZeroMQ.

=head2 Overrides

These methods should be overriden in your consuming class:

=head3 zmq_message_ready

  sub zmq_message_ready {
    my ($self, $zsock_alias, $zmq_msg, $raw_data) = @_;
    . . .
  }

Required.

The B<zmq_message_ready> method should be defined in the consuming class to
handle a received message.

Arguments are the ZMQ socket's alias, the L<ZMQ::LibZMQ3> message object, 
and the raw data retrieved from the message object, respectively.

=head3 zmq_socket_cleared

  sub zmq_socket_cleared {
    my ($self, $zsock_alias) = @_;
    . . .
  }

Optional.

Indicates a ZMQ socket has been cleared.


=head2 Attributes

=head3 context

The B<context> attribute is the ZeroMQ context object as created by
L<ZMQ::LibZMQ3/"zmq_init">.

These objects can be shared, so long as they are reset/reconstructed 
in any forked copies.


=head2 Methods

=head3 create_zmq_socket

  my $zsock = $self->create_zmq_socket( $zsock_alias, $zsock_type_constant );

Creates (and begins watching) a ZeroMQ socket.
Expects an (arbitrary) alias and a valid L<ZMQ::Constants> socket type constant.
See the man page for B<zmq_socket> for details.

If a L<POE::Session> to manage ZMQ sockets did not previously exist, one is
spawned when B<create_zmq_socket> is called.

=head3 bind_zmq_socket

  $self->bind_zmq_socket( $zsock_alias, $endpoint );

Binds a "listening" socket type to a specified endpoint.

For example:

  $self->bind_zmq_socket( 'my_serv', 'tcp://127.0.0.1:5552' );

See the man pages for B<zmq_bind> and B<zmq_connect> for details.

=head3 connect_zmq_socket

  $self->connect_zmq_socket( $zsock_alias, $target );

Connects a "client" socket type to a specified target endpoint.

See the man pages for B<zmq_connect> and B<zmq_bind> for details.

Note that ZeroMQ manages its own actual connections; 
a successful call to B<zmq_connect> does not necessarily mean a 
persistent connection is open. See the ZeroMQ documentation for details.

=head3 clear_zmq_socket

  $self->clear_zmq_socket( $zsock_alias );

Shut down a specified socket.

=head3 clear_all_zmq_sockets

  $self->clear_all_zmq_sockets;

Shut down all sockets.

=head3 get_zmq_socket

  my $zsock = $self->get_zmq_socket( $zsock_alias );

Retrieve the actual ZeroMQ socket object for the given alias.

Only useful for darker forms of magic.

=head3 write_zmq_socket

  $self->write_zmq_socket( $zsock_alias, $data );

Write raw data or a ZeroMQ message object to the specified socket alias.


=head1 SEE ALSO

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
