package POEx::ZMQ3::Requestor;

use Carp;
use Moo;
use POE;

## Keep namespace::clean above ZALIAS so subclasses can use it.
use namespace::clean;

sub ZALIAS () { 'req' }

with 'POEx::ZMQ3::Role::Emitter';

has targets => (
  is => 'ro',
  default => sub { [] },
);

sub start {
  my ($self, @endpoints) = @_;

  push @{ $self->targets }, @endpoints;

  $self->zmq->start;
  $self->zmq->create( ZALIAS, 'REQ' );

  $self->_start_emitter;
}

sub emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  $kernel->call( $self->zmq, subscribe => 'all' );

  while (my $endpoint = shift @{ $self->targets }) {
    $self->add_connect( ZALIAS, $endpoint )
  }
  1
}

after add_connect => sub {
  my ($self, $alias, $endpoint) = @_;
  $self->emit( 'connected_to', $endpoint )
};

sub stop {
  my ($self) = @_;
  $self->zmq->stop;
  $self->_shutdown_emitter;
}

sub request {
  my ($self, $data) = @_;
  $self->zmq->write( ZALIAS, $data )
}

sub zmqsock_created {}
sub zmqsock_registered {}

sub zmqsock_recv {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, undef, $data) = @_[ARG0 .. $#_];
  $self->emit( 'got_reply', $data );
}


1;

=pod

=head1 NAME

POEx::ZMQ3::Requestor - A REQ-type ZeroMQ socket

=head1 SYNOPSIS

  use POE;

  my $zreq = POEx::ZMQ3::Requestor->new();

  POE::Session->create(
    inline_states => {

      _start => sub {
        ## Connect to a ZeroMQ REP replier:
        $zreq->start( 'tcp://127.0.0.1:5665' );
        ## Subscribe to all emitted events:
        $_[KERNEL]->post( $zreq->session_id,
          'subscribe',
          'all'
        );
      },

      zeromq_connected_to => sub {
        ## Fire off a REQ to get started.
        $zreq->request('ping!')
      },

      zeromq_got_reply => sub {
        ## Got a reply from server.
        my $data = $_[ARG0];

        if ($data eq 'pong!') {
          $zreq->request('ping!')
        } else {
          warn "Don't know what to do with $data";
          $zreq->stop;
        }
      },

    },
  );

  $poe_kernel->run;

=head1 DESCRIPTION

A ZeroMQ REQ-type socket using L<POEx::ZMQ3::Role::Emitter>.

ZeroMQ REQ and REP (Requestors and Repliers) work synchronously; a REQ is
expected to start the conversation and one request should generate one reply.

=head2 Methods

=head3 start

  $zreq->start( $rep_server );

Start the Requestor and connect to a specified REP endpoint.

=head3 stop

  $zreq->stop;

Stop the Requestor, closing out the socket and stopping the event emitter.

=head3 request

  $zreq->request( $data );

Send a request to the remote end.

=head2 Events

=head3 zeromq_connected_to

Emitted when we are initialized; $_[ARG0] is the target REP server's address.

=head3 zeromq_got_reply

Emitted when we receive a reply to a request; $_[ARG0] is the raw data.

=head1 SEE ALSO

L<POEx::ZMQ3>

L<POEx::ZMQ3::Replier>

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
