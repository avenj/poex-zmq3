package POEx::ZMQ3::Sockets::ZMQSocket;


## Internal to POEx::ZMQ3::Sockets.


use 5.10.1;
use Carp;
use Moo;

has is_closing => (
  is        => 'rw',
  default   => sub { 0 },
);

has zsock => (
  is        => 'ro',
  required  => 1,
);

has handle => (
  is        => 'ro',
  required  => 1,
);

has fd => (
  is        => 'ro',
  required  => 1,
);

has buffer => (
  is        => 'rw',
  default   => sub { [] },
);

{
  package
    POEx::ZMQ3::Sockets::ZMQSocket::_BUF;

  use Carp 'confess';
  use strictures 1;

  sub DATA  () { 0 }
  sub FLAGS () { 1 }

  sub new {
    my ($class, %params) = @_;
    bless [
      ( $params{data} // confess 'Expected "data" parameter' ),
      $params{flags}
    ], $class
  }

  sub data  { $_[0]->[DATA]  }
  sub flags { $_[0]->[FLAGS] }
}

sub new_buffer_item { 
  POEx::ZMQ3::Sockets::ZMQSocket::_BUF->new( @_[1 .. $#_] )
}


1;
