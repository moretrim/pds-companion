=begin COPYRIGHT
© Copyright 2019 moretrim.

This file is part of the test suite for PFH-Tools.

To the extent possible under law, the author has waived all copyright
and related or neighboring rights to this file. This work is published
from France.

A copy of of the CC0 1.0 Universal license is also provided. If not,
see L<https://creativecommons.org/publicdomain/zero/1.0/>.
=end COPYRIGHT

use Test;
use lib 'lib';

use PDS;

=head1 Whitespace/comments

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

is-deeply soup(PDS::Grammar, pds-script), expectations;

done-testing;
