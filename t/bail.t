use Test::More;
use strict; use warnings;

BAIL_OUT
  "Bailing out because AUTOMATED_TESTING is true. ".
  "This software is deprecated and fails tests with modern libzmq. ".
  "It will be removed from CPAN in the future. ".
  "'POEx::ZMQ' ought be used instead."
 if $ENV{AUTOMATED_TESTING};

pass "Not in AUTOMATED_TESTING";

done_testing
