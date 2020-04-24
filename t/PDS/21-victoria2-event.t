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
use PDS::Styles;
use PDS::Victoria2;

my Styles:D $styles = Styles.new(Styles::never);
my PDS::Grammar:D \event-grammar = PDS::Victoria2::Events.new(source => $?FILE);

use lib 't/resources';
use vic2-model-event00;

is-deeply
    soup(event-grammar, vic2-model-event00::resource, :$styles),
    soup(PDS::Unstructured, vic2-model-event00::resource, :$styles),
    "are we parsing everything that the unstructed grammar does";

done-testing;
