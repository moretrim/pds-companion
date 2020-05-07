=begin COPYRIGHT
Copyright © 2019–2020 moretrim.

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

my Styles:D     $styles        = Styles.new(Styles::never);
my Str:D        $source        = $?FILE;
my PDS::Grammar \event-grammar = PDS::Victoria2::Events;

use lib 't/resources';
use vic2-model-event00;

is-deeply(
    PDS::soup(event-grammar, vic2-model-event00::resource, :$styles, :$source),
    PDS::soup(PDS::Unstructured, vic2-model-event00::resource, :$styles, :$source),
    "are we parsing everything that the unstructed grammar does",
);

done-testing;
