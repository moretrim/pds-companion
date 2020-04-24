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

my Styles:D $styles = Styles.new(Styles::never);

throws-like
    {
        PDS::Grammar.new.error("boom", :$styles)
    },
    X::PDS::ParseError,
    message =>
        / "Error while parsing <unspecified> at line 0:" /
        & / "boom" /,
    "exception information is propagated on throw";

sub rethrow-ok(\source = Str, *%decorations)
{
    my \source-expectations = ("‘$_’" with source) // "<unspecified>";
    my \context-expectations =
        / "Error while parsing {source-expectations} at line -1:" /
        & / "{%decorations ?? "With the following extra information:" !! '' }" /;
    my \decoration-expectations = %decorations.map({ / $(.key) ' => ' $(.value) / }).all;

    throws-like
        {
            CATCH {
                when X::PDS::ParseError {
                    .source = source;
                    .msg = "zap";
                    .line = -1;
                    for %decorations -> \deco {
                        .decorations.push(deco);
                    }
                    .rethrow
                }
            }
            PDS::Grammar.new.error("boom", :$styles)
        },
        X::PDS::ParseError,
        message =>
            context-expectations
            & decoration-expectations
            & / "zap" /,
        "exception information & decorations are propagated on rethrow";
}

rethrow-ok();
rethrow-ok("my source");
rethrow-ok(:1year);
rethrow-ok("some source", :1year);
rethrow-ok(:1year, hello => "world");
rethrow-ok("some source", :1year, hello => "world");

done-testing;
