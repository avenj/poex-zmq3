use Test::More;
use strict; use warnings qw/FATAL all/;

use_ok 'POEx::ZMQ3::Context';
my $ctxt;
ok( $ctxt = POEx::ZMQ3::Context->new, 'new context' );
ok( POEx::ZMQ3::Context->new == $ctxt, 'is a singleton' );

POEx::ZMQ3::Context->reset;
ok( POEx::ZMQ3::Context->new != $ctxt, 'reset context' );

done_testing;
