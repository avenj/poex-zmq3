package POEx::ZMQ3::Listener;

use Moo;
use POE;

use ZMQ::Constants ':all';
use ZMQ::LibZMQ;

use namespace::clean;


has emitter => (
  weak_ref  => 1,
  required  => 1,
  is        => 'ro',
);

has _ctxt => (
  required => 1,
  is       => 'ro',
  init_arg => 'context',
);

## FIXME a Listener's socket can have more than one endpoint


sub start {

}

sub stop {

}



1;
