package POEx::ZMQ3::Requestor;

use Moo;


use ZMQ::Constants 'ZMQ_REQ';

sub ZALIAS () { 'req' }

with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';

sub start {
  my ($self, $target) = @_;
  $self->_start_emitter;

  $self->create_zmq_socket( ZALIAS, ZMQ_REQ );
  $self->add_target_endpoint( ZALIAS, $target );

  $self
}

after add_target_endpoint => sub {
  my ($self, $alias, $target) = @_;
  $self->emit_now( 'connected_to', $target );
};

sub stop {
  my ($self) = @_;
  $self->emit_now( 'stopped' );
  $self->clear_zmq_socket( ZALIAS );
  $self->_stop_emitter;
}

sub request {
  my ($self, $data) = @_;
  $self->write_zmq_socket( ZALIAS, $data );
}

sub zmq_message_ready {
  my ($self, $alias, $zmsg, $data) = @_;
  $self->emit_now( 'got_reply', $data )
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

A ZeroMQ REQ-type socket using L<POEx::ZMQ3::Role::Endpoints> and
L<MooX::Role::POE::Emitter>.

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
