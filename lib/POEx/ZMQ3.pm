package POEx::ZMQ3;
our $VERSION = '0.00_01';

use Carp;
use Moo;

use namespace::clean;

## FIXME

1;


=pod

=head1 NAME

POEx::ZMQ3 - Asynchronous ZeroMQ components

=head1 SYNOPSIS

FIXME

=head1 DESCRIPTION

A set of roles and classes providing a L<POE>-enabled asynchronous interface
to B<ZeroMQ> (version 3).

=head2 Methods

FIXME

=head2 Classes

FIXME

=head2 Roles

L<POEx::ZMQ3::Role::ZMQSockets> provides the asynchronous backend that 
bridges L<POE> and L<ZMQ::LibZMQ3>.

=head1 SEE ALSO

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
