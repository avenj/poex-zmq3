use strictures 1;
use 5.10.1;

my $bind = $ARGV[0] || 'tcp://127.0.0.1:5511';

use POE;
use POEx::ZMQ3::Publisher;

POE::Session->create(
  package_states => [
    main => [ qw/
      _start
      zeromq_publishing_on
      publish
    / ],
  ],
);

sub _start {
  $_[HEAP] = POEx::ZMQ3::Publisher->new;
  $_[HEAP]->start( $bind );
  $_[KERNEL]->post( $_[HEAP]->session_id, 'subscribe', 'all' );
}

sub zeromq_publishing_on {
  my ($kern, $zpub, $sess) = @_[KERNEL, HEAP, SESSION];
  say "Publishing on $bind";
  $kern->delay( publish => 1 );
}

sub publish {
  my ($kern, $zpub) = @_[KERNEL, HEAP];
  my $ltime = localtime;
  my $utime = time;
  $zpub->publish( "The time is $ltime ($utime)" );
  $kern->delay( publish => 1 );
}

$poe_kernel->run;
