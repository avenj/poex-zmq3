package POEx::ZMQ3::Context;

use strictures 1;
use Carp 'confess';

use ZMQ::LibZMQ3 'zmq_ctx_new', 'zmq_ctx_destroy';

sub new {
  my $class = shift;
  $class = ref $class || $class;
  no strict 'refs';
  my $this = \${$class.'::_ctxt_obj'};
  # Returns the actual ZMQ::LibZMQ3 context object
  # (this class can't be instanced)
  defined $$this ? $$this : ( $$this = $class->_new(@_) )
}

sub _new {
  my ($self, $threads) = @_;
  zmq_ctx_new($threads // 1) or confess "zmq_ctx_new failed: $!"
}

sub term {
  my $class = shift;
  $class = ref $class || $class;
  my $ctxt = $class->new;
  $class->reset;
  zmq_ctx_destroy($ctxt)
}

sub reset {
  my $class = ref $_[0] || $_[0];
  no strict 'refs';
  ${$class.'::_ctxt_obj'} = undef
}

1;

=pod

=head1 NAME

POEx::ZMQ3::Context - A ZMQ context singleton

=head1 SYNOPSIS

  my $zsock = zmq_socket( 
    # ->new() returns a (lazily built) singleton:
    POEx::ZMQ3::Context->new, 
    'REQ' 
  );
  # ... if you fork later:
  POEx::ZMQ3::Context->reset;

=head1 DESCRIPTION

A ZeroMQ context should be shared amongst pieces of a single process.

This is the singleton used internally by L<POEx::ZMQ3> bits; you can use it to
retrieve the current context object if you are adding independently-managed 
L<ZMQ::LibZMQ3> sockets to the currently-running process.

Forked children should call C<< POEx::ZMQ3::Context->reset >> before 
issuing new socket operations.

Calling C<< POEx::ZMQ::Context->term >> will force a context termination.
This may block (and is rarely needed); see the man page for zmq_ctx_destroy.

=head2 METHODS

=head3 new

Retrieves the L<ZMQ::LibZMQ3> context object for the current interpreter.

The object is a singleton; if it doesn't exist when C<new> is called, it will
be created.

=head3 reset

Clears (but does not forcibly terminate, see L</term>) the current context
object.

Should be called in forked children to gain a fresh context object on the next
call to L</new>.

=head3 term

Force a context termination; calls L</reset> before issuing a C<zmq_ctx_destroy(3)>.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
