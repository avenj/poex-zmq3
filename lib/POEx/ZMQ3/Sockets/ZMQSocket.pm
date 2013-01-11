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
  use Moo;

  has data => (
    is       => 'rw',
    required => 1,
  );

  has flags => (
    is       => 'rw',
    default  => sub { undef },
  );
}

sub new_buffer_item {
  my $self = shift;
  POEx::ZMQ3::Sockets::ZMQSocket::_BUF->new(@_)
}


1;
