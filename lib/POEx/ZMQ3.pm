package POEx::ZMQ3;
our $VERSION = '0.01';
use strictures 1;

sub new {
  my $class = shift;
  require POEx::ZMQ3::Sockets;
  POEx::ZMQ3::Sockets->new
}

1;


=pod

=head1 NAME

POEx::ZMQ3 - POE-enabled asynchronous ZeroMQ components

=head1 SYNOPSIS

  use POEx::ZMQ3;
  my $zmq = POEx::ZMQ3->new;

(See L<POEx::ZMQ3::Sockets> for a more complete example.)

=head1 DESCRIPTION

A set of roles and classes providing a L<POE>-enabled asynchronous interface
to B<ZeroMQ> (version 3) via L<ZMQ::LibZMQ3>.

ZeroMQ is a powerful high-performance messaging library aimed at
concurrent/distributed applications. (If you're just getting started with
ZeroMQ, it is strongly advised you read the 'zguide'
(L<http://zguide.zeromq.org>) before jumping in.)

This is an early development release; interfaces are potentially subject to
change. Help would be welcome, of course -- jump in on GitHub: 
L<http://github.com/avenj/poex-zmq3>

=head2 Classes

L<POEx::ZMQ3::Sockets> is the backend ZMQ component. It can be used directly
to add flexible ZeroMQ functionality to your POE applications.

There are some higher-level components providing simple access to single
sockets belonging to basic types:

L<POEx::ZMQ3::Publisher> and L<POEx::ZMQ3::Subscriber> implement PUB and SUB
type ZeroMQ sockets.

L<POEx::ZMQ3::Requestor> and L<POEx::ZMQ3::Replier> implement REQ and REP type
sockets.

These are very simple base implementations. They can be subclassed or combined
in varied ways to do more powerful things.

=head2 Roles

L<MooX::Role::POE::Emitter> provides L<POE> event emitter functionality and
some endpoint management methods.

=head1 BUGS

Probably many; this software is fairly early in development.

See L<http://github.com/avenj/poex-zmq3> and feel free to report bugs via
either B<RT> or B<GitHub>.

=head1 SEE ALSO

The C<examples/> directory in the distribution and perhaps the tests in C<t/>.

L<ZMQ::LibZMQ3>

L<http://www.zeromq.org>

=head1 AUTHOR

Jon Portnoy <avenj@cobaltirc.org>

=cut
