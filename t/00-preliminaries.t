=begin COPYRIGHT
Copyright © 2019 moretrim.

This file is part of the test suite for pds-guide.

To the extent possible under law, the author has waived all copyright
and related or neighboring rights to this file. This work is published
from France.

A copy of of the CC0 1.0 Universal license is also provided. If not,
see L<https://creativecommons.org/publicdomain/zero/1.0/>.
=end COPYRIGHT

use Test;
use Test::META;

meta-ok :relaxed-name;

use-ok "PDS";
use-ok "PDS::Victoria2";

done-testing;
