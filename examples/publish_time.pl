use strictures 1;
use 5.10.1;

my $bind = $ARGV[0] || 'tcp://127.0.0.1:5511';

use POE;
use POEx::ZMQ3::Publisher;

POE::Session->create(
  heap => POEx::ZMQ3::Publisher->new,
  package_states => [
    main => [ qw/
      _start
      zeromq_publishing_on
      publish
    / ],
  ],
);

sub _start {
  my ($kern, $zpub) = @_[KERNEL, HEAP];
  $zpub->start( $bind );
  $kern->post( $zpub => 'subscribe' );
}

sub zeromq_publishing_on {
  my ($kern, $zpub) = @_[KERNEL, HEAP];
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
