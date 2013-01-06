package POEx::ZMQ3::Subscriber;

use Carp;
use Moo;

use ZMQ::Constants
  'ZMQ_SUB',
  'ZMQ_SUBSCRIBE',
;

sub ZALIAS () { 'sub' }

with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';


sub start {
  my ($self, @targets) = @_;
  $self->_start_emitter;

  $self->create_zmq_socket( ZALIAS, ZMQ_SUB );
  for my $target (@targets) {
    $self->add_target_endpoint( ZALIAS, $target );
  }

  ## Subscribe to all by default:
  $self->set_zmq_sockopt( ZALIAS, ZMQ_SUBSCRIBE, '' );

  $self
}

after add_target_endpoint => sub {
  my ($self, $alias, $target) = @_;
  $self->emit( 'subscribed_to', $target )
};

sub stop {
  my ($self) = @_;
  $self->emit( 'stopped' );
  $self->clear_zmq_socket( ZALIAS );
  $self->_stop_emitter;
}

sub zmq_message_ready {
  my ($self, $alias, $zmsg, $data) = @_;
  $self->emit( 'recv', $data )
}

1;



=pod

=head1 NAME

POEx::ZMQ3::Subscriber - A SUB-type ZeroMQ socket

=head1 SYNOPSIS

  use POE;

  my $zsub = POEx::ZMQ3::Subscriber->new();
  
  POE::Session->create(
    inline_states => {

      _start => sub {
        ## Connect to a ZeroMQ publisher:
        $zsub->start( 'tcp://127.0.0.1:5665' );

        ## Our session wants all emitted events:
        $_[KERNEL]->post( $zsub->session_id,
          'subscribe',
          'all'
        );
      },

      zeromq_subscribed_to => {
        my $target = $_[ARG0];
        print "Subscribed to $target\n";
      },

      zeromq_recv => {
        my $data = $_[ARG0];
        print "Received $data from publisher\n";

        if (++$_[HEAP]->{count} == 1000) {
          warn "I don't want any more messages :(";
          $zsub->stop;
        }
      },

    },
  );

  $poe_kernel->run;


=head1 DESCRIPTION

A lightweight ZeroMQ subscriber-type socket using
L<POEx::ZMQ3::Role::Endpoints> and L<MooX::Role::POE::Emitter> (see their
respective documentation for relevant methods).

This is a simple subscriber; it indiscriminately receives all published
messages without filtering.

=head2 Methods

=head3 start

  $zsub->start( $subscribe_to );

Start the Subscriber and connect to a specified target.

=head3 stop

  $zsub->stop;

Stop the Subscriber, closing out the socket and stopping the event emitter.

=head2 Events

=head3 zeromq_subscribed_to

Emitted when we are initialized; $_[ARG0] is the target publisher's address.

=head3 zeromq_recv

Emitted when we receive data from the publisher we are subscribed to; $_[ARG0]
is the (raw) data received. (No special handling of multipart messages
currently takes place.)

=head1 SEE ALSO

L<POEx::ZMQ3>

L<POEx::ZMQ3::Publisher>

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>


=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>


=cut
