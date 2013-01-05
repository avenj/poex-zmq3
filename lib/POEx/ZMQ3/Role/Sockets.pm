package POEx::ZMQ3::Role::Sockets;
our $VERSION = '0.00_01';

use 5.10.1;
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


use POEx::ZMQ3::Context;
sub context { POEx::ZMQ3::Context->new }

my %stringy_types = (
  REQ => ZMQ_REQ,
  REP => ZMQ_REP,

  DEALER => ZMQ_DEALER,
  ROUTER => ZMQ_ROUTER,

  PUB => ZMQ_PUB,
  SUB => ZMQ_SUB,

  XPUB => ZMQ_XPUB,
  XSUB => ZMQ_XSUB,

  PUSH => ZMQ_PUSH,
  PULL => ZMQ_PULL,

  PAIR => ZMQ_PAIR,
);


has '_zmq_sockets' => (
  ## HashRef mapping aliases to ZMQ sockets
  is      => 'ro',
  default => sub { +{} },
);

has '_zmq_zsock_sess' => (
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

  $type = $stringy_types{$type} if exists $stringy_types{$type};

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";

  my $fd = zmq_getsockopt( $zsock, ZMQ_FD ) 
    or confess "zmq_getsockopt failed: $!";
  ## We need an actual handle to feed POE:
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

## Hum. Setting ZMQ_LINGER 0 seems to cause hangs, though it ought not.
#  $self->set_zmq_sockopt($alias, ZMQ_LINGER, 0);
  zmq_close($zsock);

  $poe_kernel->call( $self->_zmq_zsock_sess,
    'zsock_giveup_socket',
    $alias
  );

  delete $self->_zmq_sockets->{$alias};

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
  ( $self->_zmq_sockets->{$alias} // return )->{zsock}
}

sub set_zmq_sockopt {
  my ($self, $alias) = splice @_, 0, 2;
  confess "Expected an alias and flag(s) to feed zmq_setsockopt"
    unless @_;

  my $zsock = $self->get_zmq_socket($alias)
    || confess "Cannot set_zmq_sockopt; no such alias $alias";

  if ( zmq_setsockopt( $zsock, @_ ) == -1 ) {
    confess "zmq_setsockopt failed: $!"
  }
}

sub write_zmq_socket {
  my ($self, $alias, $data, @params) = @_;
  confess "Expected an alias and data"
    unless defined $data;

  my $zsock = $self->get_zmq_socket($alias);
  unless (defined $zsock) {
    carp "Cannot write_zmq_socket; no such alias $alias";
    return
  }

  ## _sendmsg creates an appropriate obj if not given one:
  if ( zmq_sendmsg( $zsock, $data, @params ) == -1 ) {
    confess "zmq_sendmsg failed: $!";
  }

  $self
}


### POE
sub _zsock_handle_socket {
  my ($kernel, $self)  = @_[KERNEL, OBJECT];
  my $alias  = $_[ARG0];
  my $ref    = $self->_zmq_sockets->{$alias} // return;

  $kernel->select( $ref->{handle},
    'zsock_ready',
    undef,
    undef,
    $alias
  );

  ## See if anything was prebuffered.
  while (my $msg = zmq_recvmsg( $ref->{zsock}, ZMQ_RCVMORE )) {
    $self->zmq_message_ready( $alias, $msg, zmq_msg_data($msg) );
  }
}

sub _zsock_giveup_socket {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias  = $_[ARG0];

  my $ref    = $self->_zmq_sockets->{$alias} // return;
  my $handle = $ref->{handle};
  $kernel->select( $handle );
}

sub _zsock_ready {
  my ($self, $alias) = @_[OBJECT, ARG2];

  my $ref   = $self->_zmq_sockets->{$alias} // return;

  ## FIXME
  ## Hum. Handle multipart specially?

  ## Dispatch to consumer's handler.
  while (my $msg = zmq_recvmsg( $ref->{zsock}, ZMQ_RCVMORE )) {
    $self->zmq_message_ready( $alias, $msg, zmq_msg_data($msg) );
  }
}

sub _zsock_start { 1 }


1;

=pod

=head1 NAME

POEx::ZMQ3::Role::Sockets - Add ZeroMQ sockets to a class

=head1 SYNOPSIS

  ## A 'REP' (reply) server that pongs mindlessly, given a ping.
  ## (Call ->start() from a POE-enabled class/app.)
  package MyZMQServer;
  use Moo;
  use ZMQ::Constants ':all';

  with 'POEx::ZMQ3::Role::Sockets';

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

Methods usually die with a stack trace on failure. (See L<Try::Tiny> if this
is not quite what you wanted.)

See L<http://www.zeromq.org> for more about ZeroMQ.

This module has been tested against B< zeromq-3.2.2 > and 
B< ZMQ::LibZMQ3-1.03 >.
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
Expects an (arbitrary) alias and a valid L<ZMQ::Constants> socket type
constant or a string mapping to such:

  ## Same:
  $self->create_zmq_socket( $zsock_alias, 'PUB' );
  use ZMQ::Constants ':all';
  $self->create_zmq_socket( $zsock_alias, ZMQ_PUB );

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


=head3 set_zmq_sockopt

  $self->set_zmq_sockopt( $zsock_alias, @params );

Calls B<zmq_setsockopt> to set options on the specified ZMQ socket.

Most options should be set between socket creation and any initial
L</connect_zmq_socket> or L</bind_zmq_socket> call. See the man page.

=head3 write_zmq_socket

  $self->write_zmq_socket( $zsock_alias, $data );

Write raw data or a ZeroMQ message object to the specified socket alias.

Optional extra params can be passed on to B<zmq_sendmsg>.

=head1 SEE ALSO

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
