=begin COPYRIGHT
Copyright © 2019–2021 moretrim.

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

my Styles:D       $styles       = Styles.new(Styles::never);
my Str:D          $source       = $?FILE;
my PDS::Grammar   \test-grammar = PDS::Unstructured;

use lib 't/resources';
use vic2-model-event00;

my \script = vic2-model-event00::resource;

# not exhaustive, takes enough time already
my @locs = flat 2 xx 11, 42 xx 5, 89 xx 11, 132 xx 12, 178 xx 30, 250 xx 28, 304 xx 23, 358 xx 128;
for 1..64 Z @locs -> (\which, \loc) {
    throws-like(
        { PDS::soup(test-grammar, script.subst('}', '', nth => which), :$styles, :$source) },
        X::PDS::ParseError,
        message => / "Around line " $(loc) ":" / & / "expected closing '}'" /,
        "malformed input is missing closing brace number {which}, context expected around line {loc}",
    );
}

my \openers = script.comb('{').elems;

throws-like(
    { PDS::soup(test-grammar, script.subst('{', '', nth => 1), :$styles, :$source) },
    X::PDS::ParseError,
    message => / "At the start of the script" / & / "rejected by grammar PDS::Unstructured" /,
    "malformed input was missing opening brace number 1",
);

@locs = 2, 6, 2, 15, 15, 2, 33, 33, 37, 37;
for 2..* Z @locs -> (\which, \loc) {
    throws-like(
        { PDS::soup(test-grammar, script.subst('{', '', nth => which), :$styles, :$source) },
        X::PDS::ParseError,
        message => / "Around line " $(loc) ":" / & / "expected closing '}'" /,
        "malformed input was missing opening brace number {which}, context expected around {loc}",
    );
}

throws-like(
    { PDS::soup(test-grammar, script.subst('{', '', nth => 12), :$styles, :$source) },
    X::PDS::ParseError,
    message => / "At the start of the script" / & / "rejected by grammar PDS::Unstructured" /,
    "malformed input was missing opening brace number 12",
);

@locs = flat 202, 212 xx 2, 202 xx 2, 217 xx 2;
for 51..* Z @locs -> (\which, \loc) {
    throws-like(
        { PDS::soup(test-grammar, script.subst('{', '', nth => which), :$styles, :$source) },
        X::PDS::ParseError,
        message => / "Around line " $(loc) ":" / & / "expected closing '}'" /,
        "malformed input was missing opening brace number {which}, context expected around {loc}",
    );
}

done-testing;
