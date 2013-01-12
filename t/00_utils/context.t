use Test::More;
use strict; use warnings qw/FATAL all/;

use_ok 'ZMQ::LibZMQ3';
my ($maj, $min, $pat) = ZMQ::LibZMQ3::zmq_version();
my $str = join '.', $maj, $min, $pat;
unless ($maj == 3 && $min >= 2 && $pat >= 2) {
  diag "Warning; tested with zeromq 3.2.2+ but this is $str";
} else {
  diag "Testing with zeromq $str";
}

use_ok 'POEx::ZMQ3::Context';
my $ctxt;
ok( $ctxt = POEx::ZMQ3::Context->new, 'new context' );
ok( POEx::ZMQ3::Context->new == $ctxt, 'is a singleton' );

POEx::ZMQ3::Context->reset;
ok( POEx::ZMQ3::Context->new != $ctxt, 'reset context' );

done_testing;
