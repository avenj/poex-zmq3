package POEx::ZMQ3::Connector;

use Carp;
use Moo;
use POE;

use ZMQ::Constants ':all';
use ZMQ::LibZMQ3;

use namespace::clean;

has emitter => (
  weak_ref => 1,
  required => 1,
  is       => 'ro',
);

has _ctxt => (
  required => 1,
  is       => 'ro',
  init_arg => 'context',
);


## FIXME


sub start {

}

sub stop {

}


