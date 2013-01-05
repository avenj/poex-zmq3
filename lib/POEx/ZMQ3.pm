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

POEx::ZMQ3::Server # FIXME return appropriate subclass?

POEx::ZMQ3::Client # FIXME similar to above?

=head2 Roles

L<POEx::ZMQ3::Role::Sockets> is a fast asynchronous L<POE> interface 
to L<ZMQ::LibZMQ3> sockets.

L<MooX::Role::POE::Emitter> provides L<POE> event emitter functionality.

=head1 SEE ALSO

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
