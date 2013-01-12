use Test::More;
use strict; use warnings qw/FATAL all/;

use POEx::ZMQ3 qw/
  Publisher
  Subscriber
/;

ok( POEx::ZMQ3::Publisher->can('new'), 'First module loaded' );
ok( POEx::ZMQ3::Subscriber->can('new'), 'Second module loaded' );
isa_ok( POEx::ZMQ3->new, 'POEx::ZMQ3::Sockets' );

done_testing;
