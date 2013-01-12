package POEx::ZMQ3::Subscriber;

use Carp;
use Moo;
use POE;

## FIXME
##  Easier subscription management wrt. multipart_recv

use namespace::clean;

has targets => (
  is => 'rw',
  default => sub { [] },
);

sub ZALIAS () { 'sub' }

with 'POEx::ZMQ3::Role::Emitter';

sub build_defined_states {
  my ($self) = @_;
  [
    $self => [ qw/
      emitter_started
      zmqsock_recv
      zmqsock_multipart_recv
    / ],
  ]
}

sub start {
  my ($self, @targets) = @_;
  push @{ $self->targets }, @targets;
  $self->zmq->start;
  $self->zmq->create( ZALIAS, 'SUB' );

  $self->_start_emitter;
}

sub emitter_started {
  my ($kernel, $self) = @_[KERNEL, OBJECT];

  $kernel->call( $self->zmq => subscribe => 'all' );
  $self->zmq->set_zmq_subscribe( ZALIAS );
  $self->add_connect( ZALIAS, $_ ) for @{ $self->targets };
  $self->targets([]);

  $self
}

after add_connect => sub {
  my ($self, $alias, $target) = @_;
  $self->emit( 'subscribed_to', $target )
};

sub stop {
  my ($self) = @_;
  $self->zmq->stop;
  $self->_stop_emitter;
}

sub zmqsock_recv {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $data) = @_[ARG0, ARG1];
  $self->emit( 'received', $data )
}

sub zmqsock_multipart_recv {
  my ($kernel, $self) = @_[KERNEL, OBJECT];
  my ($alias, $parts) = @_[ARG0, ARG1];
  ## FIXME
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

      zeromq_received => {
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
L<POEx::ZMQ3::Role::Emitter>.

This is a simple subscriber; by default it indiscriminately receives all published
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

=head3 zeromq_received

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
