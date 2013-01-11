package POEx::ZMQ3;
our $VERSION = '0.00_11';

## FIXME

1;


=pod

=head1 NAME

POEx::ZMQ3 - POE-enabled asynchronous ZeroMQ components

=head1 SYNOPSIS

  This is an early development release.
  Many pieces are missing, including this SYNOPSIS.

=head1 DESCRIPTION

A set of roles and classes providing a L<POE>-enabled asynchronous interface
to B<ZeroMQ> (version 3).

This is an early development release.
GitHub: L<http://github.com/avenj/poex-zmq3>

=head2 Classes

L<POEx::ZMQ3::Sockets> is the backend ZMQ component. It can be used directly
to add ZeroMQ functionality to your POE applications.

L<POEx::ZMQ3::Publisher> and L<POEx::ZMQ3::Subscriber> implement PUB and SUB
type ZeroMQ sockets.

L<POEx::ZMQ3::Requestor> and L<POEx::ZMQ3::Replier> implement REQ and REP type
sockets.

These are very simple base implementations.

=head2 Roles

L<MooX::Role::POE::Emitter> provides L<POE> event emitter functionality and
some endpoint management methods.

=head1 SEE ALSO

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
