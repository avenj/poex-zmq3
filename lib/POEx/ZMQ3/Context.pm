package POEx::ZMQ3::Context;
use strictures 1;
use Carp 'confess';

use ZMQ::LibZMQ3 'zmq_ctx_new', 'zmq_ctx_destroy';

sub new {
  my $class = shift;
  $class = ref $class || $class;
  no strict 'refs';
  my $this = \${$class.'::_ctxt_obj'};
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

POEx::ZMQ3::Context - A ZeroMQ context singleton

=head1 SYNOPSIS

  ## new() returns (lazy build) singleton:
  my $zsock = zmq_socket( POEx::ZMQ3::Context->new, $type );
  ## ... if you fork later:
  POEx::ZMQ3::Context->reset;

=head1 DESCRIPTION

A ZeroMQ context should be shared amongst pieces of a single process.

This is the singleton used internally by L<POEx::ZMQ3> bits.

Forked children should call C<< POEx::ZMQ3::Context->reset >> before 
issuing new socket operations.

Calling C<< POEx::ZMQ::Context->term >> will force a context termination.
This may block (and is rarely needed); see the man page for zmq_ctx_destroy.

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
