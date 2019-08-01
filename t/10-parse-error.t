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
use lib 'lib';

use PDS;

throws-like
    {
        PDS::Grammar.new.error("boom")
    },
    X::PDS::ParseError,
    message =>
        / "While parsing <unspecified>" /
        & / "Cannot parse input: boom" /
        & / "at line 0" /,
    "exception information is propagated on throw";

sub rethrow-ok(\source = Str, *%decorations)
{
    my \source-expectations = ("‘$_’" with source) // "<unspecified>";
    my \header-expectations = / "While parsing {source-expectations}{%decorations ?? " with the following extra information:" !! '' }" /;
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
            PDS::Grammar.new.error("boom")
        },
        X::PDS::ParseError,
        message =>
            header-expectations
            & decoration-expectations
            & / "Cannot parse input: zap" /
            & / "at line -1" /,
        "exception information & decorations are propagated on rethrow";
}

rethrow-ok();
rethrow-ok("my source");
rethrow-ok(:1year);
rethrow-ok("some source", :1year);
rethrow-ok(:1year, hello => "world");
rethrow-ok("some source", :1year, hello => "world");

done-testing;
