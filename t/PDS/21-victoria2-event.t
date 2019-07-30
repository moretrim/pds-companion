=begin COPYRIGHT
Copyright © 2019 moretrim.

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

my PDS::Grammar \test-grammar = PDS::Grammar.new(source => $?FILE);

use lib 't/resources';
use vic2-model-event00;

is-deeply
    soup(test-grammar, vic2-model-event00::resource),
    soup(PDS::Grammar, vic2-model-event00::resource),
    "are we parsing everything that the base grammar does";

done-testing;
