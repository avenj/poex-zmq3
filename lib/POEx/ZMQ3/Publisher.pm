package POEx::ZMQ3::Publisher;

use Carp;
use Moo;
use POE;

use namespace::clean;

sub ZALIAS () { 'pub' }

with 'POEx::ZMQ3::Role::Emitter';

sub build_defined_states {[]}

sub start {
  my ($self, @endpoints) = @_;
  $self->zmq->start;
  $self->zmq->create( ZALIAS, 'PUB' );
  $self->_start_emitter;
  $self->add_bind( ZALIAS, $_ ) for @endpoints;
  $self
}

after add_bind => sub {
  my ($self, $alias, $endpoint) = @_;
  $self->emit( 'publishing_on', $endpoint );
};

sub stop {
  my ($self) = @_;
  $self->zmq->stop;
  $self->_stop_emitter;
}

sub publish {
  my ($self, @data) = @_;
  $self->zmq->write( ZALIAS, $_ ) for @data;
}

sub publish_multipart {
  my ($self, @data) = @_;
  $self->zmq->write_multipart( ZALIAS, @data );
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
        $zpub->start(
          'tcp://127.0.0.1:5665',
          'tcp://127.0.0.1:1234',
        );

        ## Our session wants all emitted events:
        $_[KERNEL]->post( $zpub->session_id,
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
        $zpub->publish(
          'This is data \o/'
        );

        $_[KERNEL]->delay( push_messages => 1 );
      },
    }
  );

  $poe_kernel->run;

=head1 DESCRIPTION

A lightweight ZeroMQ publisher-type socket using L<POEx::ZMQ3::Role::Emitter>.

=head2 Methods

=head3 start

  $zpub->start( @publish_on );

Start the Publisher and bind some endpoint(s).

=head3 stop

  $zpub->stop;

Stop the Publisher, closing out the socket and stopping the event emitter.

=head3 publish

  $zpub->publish( @data );

Publish some item(s) to the ZeroMQ socket as individual single-part messages.

This base class does no special serialization on its own.

=head3 publish_multipart

  $zpub->publish_multipart( @data );

Publish multi-part data. For PUB-type sockets, this is frequently used to
create message envelopes a SUB-type socket can subscribe to:

  $zpub->publish_multipart( $prefix, $data );

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
