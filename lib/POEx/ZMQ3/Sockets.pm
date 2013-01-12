package POEx::ZMQ3::Sockets;

use 5.10.1;
use Carp;
use Moo;
use POE;
require POSIX;

use ZMQ::LibZMQ3;
use ZMQ::Constants 
  ## Socket types.
  qw/
    ZMQ_REQ ZMQ_REP
    ZMQ_DEALER ZMQ_ROUTER

    ZMQ_PUB ZMQ_SUB
    ZMQ_XPUB ZMQ_XSUB

    ZMQ_PUSH ZMQ_PULL

    ZMQ_PAIR
 /,
 ## Socket control.
 qw/
   ZMQ_EVENTS
   ZMQ_FD 
   ZMQ_LINGER
   ZMQ_POLLIN
   ZMQ_SUBSCRIBE
 /,
 ## Send/recv.
 qw/
   ZMQ_DONTWAIT
   ZMQ_RCVMORE ZMQ_SNDMORE
 /,
 ;


with 'MooX::Role::POE::Emitter';
use MooX::Role::Pluggable::Constants;

require POEx::ZMQ3::Sockets::ZMQSocket;
sub ZMQSocket () { 'POEx::ZMQ3::Sockets::ZMQSocket' }

require POEx::ZMQ3::Context;
has context => (
  is      => 'ro',
  default => sub { POEx::ZMQ3::Context->new },
);

has _zmq_sockets => (
  is      => 'ro',
  default => sub { +{} },
);


my %stringy_types = (
  REQ     => ZMQ_REQ,
  REP     => ZMQ_REP,
  DEALER  => ZMQ_DEALER,
  ROUTER  => ZMQ_ROUTER,

  PUB     => ZMQ_PUB,
  SUB     => ZMQ_SUB,
  XPUB    => ZMQ_XPUB,
  XSUB    => ZMQ_XSUB,
  PUSH    => ZMQ_PUSH,
  PULL    => ZMQ_PULL,

  PAIR    => ZMQ_PAIR,
);


sub BUILD {
  my ($self) = @_;

  $self->set_event_prefix( 'zmqsock_' )
    unless $self->has_event_prefix;

  $self->set_register_prefix( 'ZMQSock_' )
    unless $self->has_register_prefix;

  $self->set_shutdown_signal( 'SHUTDOWN_ZMQSOCKETS' )
    unless $self->has_shutdown_signal;

  $self->set_object_states([
    $self => {
      zsock_ready   => '_zsock_ready',
      zsock_watch   => '_zsock_watch',
      zsock_unwatch => '_zsock_unwatch',
      zsock_write   => '_zsock_write',
      
      create      => '_zpub_create',
      close       => '_zpub_close',
      bind        => '_zpub_bind',
      connect     => '_zpub_connect',
      write       => '_zpub_write',
      write_multipart => '_zpub_write_multi',
    },
    $self => [
      'emitter_started',
      'emitter_stopped',
    ],
  ]);
}


sub start {
  my ($self) = @_;
  $self->_start_emitter;
}

sub stop {
  my ($self) = @_;
  $self->_zmq_clear_all;
  ## Yes, I'm serious.
  ## (Gives zmq a little extra cleanup time after zmq_close.)
  $self->yield(sub { $_[OBJECT]->yield('shutdown_emitter') });
}

sub emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

}

sub emitter_stopped {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_zmq_clear_all;
}

sub get_zmq_socket {
  my ($self, $alias) = @_;
  confess "Expected an alias" unless defined $alias;
  my $struct = $self->_zmq_sockets->{$alias} || return;
  $struct->zsock
}

## FIXME POE interfaces to sockopt setters
sub set_zmq_sockopt {
  my ($self, $alias) = splice @_, 0, 2;
  confess "Expected an alias and params to feed zmq_setsockopt"
    unless @_;

  my $zsock = $self->get_zmq_socket($alias)
    || confess "Cannot set_zmq_sockopt; no such alias $alias";
  
  if ( zmq_setsockopt($zsock, @_) == -1 ) {
    confess "zmq_setsockopt failed; $!"
  }

  $self
}

sub set_zmq_subscribe {
  ## Common sockopt.
  my ($self, $alias, $to) = @_;
  $to //= '';
  $self->set_zmq_sockopt( $alias, ZMQ_SUBSCRIBE, $to )
}

sub create {
  my $self = shift;
  $self->call( 'create', @_ )
}

sub _zpub_create {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $self->_zmq_create_sock( @_[ARG0 .. $#_] )
}

sub bind {
  my $self = shift;
  $self->yield( 'bind', @_ )
}

sub _zpub_bind {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $endpt) = @_[ARG0 .. $#_];
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpt;

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot bind; no such alias $alias";
  zmq_bind($zsock, $endpt) and confess "zmq_bind failed; $!";

  $self->emit( 'bind_added', $alias, $endpt )
}


sub connect {
  my $self = shift;
  $self->yield( 'connect', @_ )
}

sub _zpub_connect {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $endpt) = @_[ARG0 .. $#_];
  confess "Expected an alias and endpoint"
    unless defined $alias and defined $endpt;

  my $zsock = $self->get_zmq_socket($alias)
    or confess "Cannot connect; no such alias $alias";
  zmq_connect($zsock, $endpt) and confess "zmq_connect failed; $!";

  $self->emit( 'connect_added', $alias, $endpt )
}


sub write {
  my $self = shift;
  $self->yield( 'write', @_ )
}

sub write_multipart {
  my $self = shift;
  $self->yield( 'write_multipart', @_ )
}

sub _zpub_write_multi {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, @parts) = @_[ARG0 .. $#_];

  my $ref = $self->_zmq_sockets->{$alias}
    || confess "Cannot queue write; no such alias $alias";
  while (my $data = shift @parts) {
    my $item = ZMQSocket->new_buffer_item(
      data => $data, 
      (scalar(@parts) ? (flags => ZMQ_SNDMORE) : () ),
    );
    push @{ $ref->buffer }, $item;
  }
  ## These are call()ed, as we likely were already reached via yield/post:
  $self->call( 'zsock_write', $alias )
}

sub _zpub_write {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $data, $flags) = @_[ARG0 .. $#_];

  my $ref = $self->_zmq_sockets->{$alias}
    || confess "Cannot queue write; no such alias $alias";
  my $item = ZMQSocket->new_buffer_item(data => $data, flags => $flags);
  push @{ $ref->buffer }, $item;

  $self->call( 'zsock_write', $alias )
}

sub _zsock_write {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $struct = $self->_zmq_sockets->{$alias}
    || confess "Cannot execute write; no such alias $alias";

  return unless @{ $struct->buffer };

  my $next  = $struct->buffer->[0];
  my $data  = $next->data;
  my $flags = $next->flags;
  unless (ref $data) {
    $data = zmq_msg_init_data($data)
  }

  ## This socket may change state without necessarily
  ## triggering read events. See zmq_getsockopt docs.
  $self->yield( zsock_ready => undef, 0, $alias );
  $self->yield( zsock_write => $alias );

  my $rc;
  if ( $rc = zmq_msg_send( $data, $struct->zsock, ($flags ? $flags : ()) ) 
      && ($rc//0) == -1 ) {

    unless ($rc == POSIX::EAGAIN || $rc == POSIX::EINTR) {
      confess "zmq_msg_send failed; $!";
    }
  } else {
    ## Successfully queued on socket.
    shift @{ $struct->buffer }
  }
}


sub close {
  my $self = shift;
  $self->yield( 'close', @_ )
}

sub _zpub_close {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  $self->_zmq_clear_sock($alias);
  $self->emit( 'closing', $alias );
}

## Workers.

sub _zsock_ready {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my (undef, $mode, $alias) = @_[ARG0 .. $#_];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to read socket '$alias' but no such socket struct";
    return
  }

  my $zev = zmq_getsockopt($struct->zsock, ZMQ_EVENTS);
  return unless defined $zev
    and $zev & ZMQ_POLLIN == ZMQ_POLLIN;
  ## Socket can change state after a write/read without notifying us.
  ## Check again when we're finished.
  $self->yield( zsock_ready => undef, 0, $alias );

  if ($struct->is_closing) {
    warn "Socket '$alias' ready but closing"
      if $ENV{POEX_ZMQ_DEBUG};
    return
  }

  my @parts;
  RECV: while (1) {
    my $msg = zmq_msg_init;
    if ( zmq_msg_recv($msg, $struct->zsock, ZMQ_DONTWAIT) == -1 ) {
      if ($! == POSIX::EAGAIN || $! == POSIX::EINTR) {
        $self->yield(zsock_ready => undef, 0, $alias);
        return
      }
      confess "zmq_msg_recv failed; $!"
    }

    my $data = zmq_msg_data($msg);

    unless ( zmq_getsockopt($struct->zsock, ZMQ_RCVMORE) ) {
      ## No parts remaining on socket.
      if (@parts) {
        ## Multi-part message accumulated.
        $self->emit( multipart_recv => 
          $alias, [ @parts, $data ] 
        )
      } else {
        ## Single-part message.
        $self->emit( recv =>
          $alias, $data
        )
      }
      last RECV
    }
    ## Multi-part with more parts to follow.
    push @parts, $data;
  }

  1  
}

sub _zmq_create_sock {
  my ($self, $alias, $type) = @_; 
  confess "Expected an alias and sock type"
    unless defined $alias and defined $type;

  $type = $stringy_types{$type} if exists $stringy_types{$type};

  my $zsock = zmq_socket( $self->context, $type )
    or confess "zmq_socket failed: $!";

  my $fd = zmq_getsockopt( $zsock, ZMQ_FD )
    or confess "zmq_getsockopt failed: $!";

  open(my $fh, '<&=', $fd ) or confess "failed fdopen: $!";

  $self->_zmq_sockets->{$alias} = ZMQSocket->new(
    zsock  => $zsock,
    handle => $fh,
    fd     => $fd,
  );

  ## FIXME adjust IPV4ONLY if we have ->use_ipv6 or so?
  $self->set_zmq_sockopt($alias, ZMQ_LINGER, 0);

  $self->emit( 'created', $alias, $type );

  $self->call( zsock_watch => $alias )
}

sub _zsock_watch {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my $alias = $_[ARG0];
  my $struct = $self->_zmq_sockets->{$alias};
  unless ($struct) {
    warn "Attempted to watch $alias but no such socket?";
    return
  }

  $kernel->select( $struct->handle,
    'zsock_ready',
    undef, undef,
    $alias
  );

  1
}

sub _zsock_unwatch {
  my ($kernel, $self, $alias) = @_[KERNEL, OBJECT, ARG0];
  my $struct = delete $self->_zmq_sockets->{$alias};
  $kernel->select( $struct->handle )
}

sub _zmq_clear_sock {
  my ($self, $alias) = @_;

  my $zsock = $self->get_zmq_socket($alias);

  zmq_close($zsock);
  $self->_zmq_sockets->{$alias}->is_closing(1);
  
  $self->yield( zsock_unwatch => $alias )
}

sub _zmq_clear_all {
  my ($self) = @_;
  $self->_zmq_clear_sock($_) for keys %{ $self->_zmq_sockets }
}

1;


=pod

=head1 NAME

POEx::ZMQ3::Sockets - POE ZeroMQ Component

=head1 SYNOPSIS

  ## A 'REQ' client that sends 'PING' to a REP on localhost:5050
  use strictures 1;
  use POE;
  use POEx::ZMQ3::Sockets;

  POE::Session->create(
    package_states => [
      main => [ qw/
        _start
        zmqsock_registered
        zmqsock_recv
      / ],
    ]
  );

  sub _start {
    my ($kern, $heap) = @_[KERNEL, HEAP];
    my $zmq = POEx::ZMQ3::Sockets->new;

    $zmq->start;

    $heap->{zmq} = $zmq;

    $kern->call( $zmq->session_id, 'subscribe', 'all' );
  }

  sub zmqsock_registered {
    my ($kern, $heap) = @_[KERNEL, HEAP];
    my $zmq = $heap->{zmq};

    $zmq->create( 'pinger', 'REQ' );

    $zmq->connect( 'pinger', 'tcp://127.0.0.1:5050' );

    $zmq->write( 'pinger', 'PING' );
  }

  sub zmqsock_recv {
    my ($kern, $heap) = @_[KERNEL, HEAP];
    my ($alias, $data) = @_[ARG0 .. $#_];

    if ($data eq 'PONG') {
      ## Got a PONG. Send another PING:
      $zmq->write( 'pinger', 'PING' );
    }
  }

  $poe_kernel->run;

=head1 DESCRIPTION

This is the backend L<MooX::Role::POE::Emitter> session behind L<POEx::ZMQ3>,
integrating ZeroMQ (L<http://www.zeromq.org>) with a L<POE> event loop.

=head2 Registering Sessions

Your L<POE::Session> should register with the component to receive events:

  ## Inside a POE::Session
  ## Get all events from component in $_[HEAP]->{zmq}:
  sub my_start {
    my $zmq = $_[HEAP]->{zmq};
    $_[KERNEL]->call( $zmq->session_id, 'subscribe', 'all' );
  }

See L</POE API> for more on events emitted and accepted by this component.

See L<MooX::Role::POE::Emitter> for more details on event emitters; the
documentation regarding event prefixes and session details lives there.

=head2 Methods

=head3 start

Takes no arguments.

Spawns the L<MooX::Role::POE::Emitter> session that controls ZMQ socket
handling. Must be called prior to operating on sockets.

=head3 stop

Takes no arguments.

Stops the component, closing out all active sockets.

=head3 create

Takes a socket alias and a socket type.

Creates a new ZeroMQ socket. The socket is not initially bound/connected to
anything; see L</bind>, L</connect>.

The socket type may be either a constant from L<ZMQ::Constants> or a
string type:

  ## Equivalent:

  $zmq->create( $alias, 'PUB' );

  use ZMQ::Constants 'ZMQ_PUB';
  $zmq->create( $alias, ZMQ_PUB );

See the B<zmq_socket> man page for details.

=head3 bind

Takes a socket alias and an endpoint to listen for connections on.

The opposite of L</bind> is L</connect>

=head3 connect

Takes a socket alias and a target endpoint to connect to.

Note that ZeroMQ manages its own connections asynchronously.
A successful L</bind> or L</connect> is not necessarily indicative of a
positively usable connection.

=head3 write

Takes a socket alias, some data (as a scalar), and optional flags to pass to
ZeroMQ's B<zmq_msg_send>:

  ## Write a simple message:
  $zmq->write( $alias, 'A message' );

  ## Write some serialized data:
  my $ref  = { things => 'some data' };
  my $data = Storable::nfreeze( $ref );
  $zmq->write( $alias, $data );

Writes data to the ZMQ socket, when possible.

Also see L</write_multipart>.

=head3 write_multipart

Takes a socket alias and a list of scalar data items to send as a multi-part
message:

  $zmq->write_multipart( $alias, $header, $content );

See the ZeroMQ documentation for details regarding multi-part messages.

Also see L</zmqsock_multipart_recv>

=head3 close

Takes a socket alias.

Closes the specified ZMQ socket.

=head3 context

Takes no arguments.

Returns the current L<POEx::ZMQ3::Context> object.

=head3 get_zmq_socket

Takes a socket alias.

Returns the actual L<ZMQ::LibZMQ3> socket object.

=head3 set_zmq_sockopt

Takes a socket alias and arbitrary flags/options to pass to
B<zmq_setsockopt>.

See the man page for B<zmq_setsockopt>.

=head3 set_zmq_subscribe

Takes a socket alias and an optional subscription prefix.

Calls L</set_zmq_sockopt> to set the C<ZMQ_SUBSCRIBE> flag for the specified
socket; this is used by SUB-type sockets to subscribe to messages.

If no subscription prefix is specified, the socket will be subscribed to all
messages.

=head2 POE API

=head3 Emitted Events

=head4 zmqsock_bind_added

Emitted when a L</bind> has been executed.

$_[ARG0] is the socket's alias.

$_[ARG1] is the endpoint string.

=head4 zmqsock_connect_added

Emitted when a L</connect> has been executed.

$_[ARG0] is the socket's alias.

$_[ARG1] is the endpoint string.

=head4 zmqsock_recv

Emitted when some data has been received on a socket.

$_[ARG0] is the socket's alias.

$_[ARG1] is the raw message data extracted via B<zmq_msg_data>.

=head4 zmqsock_multipart_recv

Emitted when multipart data has been received on a socket.

$_[ARG0] is the socket's alias.

$_[ARG1] is an ARRAY containing the raw data extracted from each message part.

=head4 zmqsock_created

Emitted when a socket has been created.

$_[ARG0] is the alias that was spawned.

$_[ARG1] is the socket's type, as a L<ZMQ::Constants> constant.

=head4 zmqsock_closing

Emitted when a socket is being shut down.

$_[ARG0] is the alias that is closing.

=head3 Accepted Events

The following events take the same parameters as their counterparts described
in L</Methods>:

=over

=item *

create

=item *

close

=item *

bind

=item *

connect

=item *

write

=item *

write_multipart

=back

=head1 SEE ALSO

L<POEx::ZMQ3>

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
