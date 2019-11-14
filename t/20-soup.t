=begin COPYRIGHT
Copyright © 2019 moretrim.

This file is part of the test suite for pds-companion.

To the extent possible under law, the author has waived all copyright
and related or neighboring rights to this file. This work is published
from France.

A copy of of the CC0 1.0 Universal license is also provided. If not,
see L<https://creativecommons.org/publicdomain/zero/1.0/>.
=end COPYRIGHT

use Test;
use lib 'lib';

use PDS;

my PDS::Grammar \test-grammar = PDS::Unstructured.new(source => $?FILE);

my \pds-script = q:to«END»;
  # a
hello  # b
  # c
    =  world  # d

# e

"hallo"  # f

# g


= welt
END

my \expectations = [
    'hello' => 'world',
    '"hallo"' => 'welt',
];

is-deeply soup(test-grammar, pds-script), expectations, "can we handle whitespace and comments";

done-testing;
