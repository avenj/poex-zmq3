package POEx::ZMQ3::Publisher;

use Moo;

use ZMQ::Constants
  'ZMQ_PUB',
  'ZMQ_SNDMORE'
;

sub ZALIAS () { 'pub' }

with 'POEx::ZMQ3::Role::Emitter';
with 'POEx::ZMQ3::Role::Endpoints';


sub start {
  my ($self, @endpoints) = @_;
  $self->_start_emitter;
  $self->create_zmq_socket( ZALIAS, ZMQ_PUB );
  $self->add_endpoint( ZALIAS, $_ ) for @endpoints;
  $self
}

after add_endpoint => sub {
  my ($self, $alias, $endpoint) = @_;
  $self->emit( 'publishing_on', $endpoint );
};

sub stop {
  my ($self) = @_;
  $self->emit( 'stopped' );
  $self->clear_zmq_socket( ZALIAS );
  $self->_stop_emitter;
  $self
}

sub publish {
  my ($self, @data) = @_;
  $self->yield(sub { $self->write_zmq_socket( ZALIAS, $_ ) for @data });
  $self
}

sub publish_multipart {
  my ($self, @data) = @_;
  $self->yield(sub {
    while (my $data = shift @data) {
      $self->write_zmq_socket(
        ZALIAS, $data, (@data ? ZMQ_SNDMORE : () ) 
      )
    }
  });
  $self
}

sub zmq_message_ready {
  ## A Publisher is one-way.
}

1;

=pod

=head1 NAME

POEx::ZMQ3::Publisher - A PUB-type ZeroMQ socket

=head1 SYNOPSIS

  use POE;

  my $zpub = POEx::ZMQ3::Publisher->new();

  POE::Session->create(
    inline_states => {

      _start => sub {
        ## Bind our Publisher to some endpoints:
        $zsub->start(
          'tcp://127.0.0.1:5665',
          'tcp://127.0.0.1:1234',
        );

        ## Our session wants all emitted events:
        $_[KERNEL]->post( $zsub->session_id,
          'subscribe',
          'all'
        );

        ## Push messages on a timer loop forever:
        $_[KERNEL]->delay( push_messages => 1 );
      },

      zeromq_publishing_on => sub {
        my $endpoint = $_[ARG0];
        print "Publishing on $endpoint\n";
      },

      push_messages => sub {
        $zsub->publish(
          'This is data \o/'
        );

        $_[KERNEL]->delay( push_messages => 1 );
      },
    }
  );

  $poe_kernel->run;

=head1 DESCRIPTION

A lightweight ZeroMQ publisher-type socket using
L<POEx::ZMQ3::Role::Endpoints> and L<MooX::Role::POE::Emitter> (see their
respective documentation for relevant methods).

=head2 Methods

=head3 start

  $zsub->start( @publish_on );

Start the Publisher and bind some endpoint(s).

=head3 stop

  $zsub->stop;

Stop the Publisher, closing out the socket and stopping the event emitter.

=head3 publish

  $zsub->publish( @data );

Publish some item(s) to the ZeroMQ socket.

This base class does no special serialization on its own.

=head3 publish_multipart

  $zsub->publish_multipart( $envelope, @data );

Publish a multipart message.

See the ZeroMQ documentation for more on multipart messages.

=head2 Events

=head3 zeromq_publishing_on

Emitted when we are initialized; $_[ARG0] is the endpoint we are publishing
on.

=head1 SEE ALSO

L<POEx::ZMQ3>

L<POEx::ZMQ3::Subscriber>

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
