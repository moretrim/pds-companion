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

my Styles:D     $styles       = Styles.new(Styles::never);
my Str:D        $source       = $?FILE;

# fatal-error unit tests use C<.new> to circumvent language rules
# in actual practice, L<fatal-error> is called on concrete L<Match> results

throws-like(
    {
        PDS::Grammar.new.fatal-error("boom", :$styles, :$source)
    },
    X::PDS::ParseError,
    message => / "At the start of the script" / & / "boom" /,
    "exception information is propagated on throw",
);

sub rethrow-ok(\source = Str, *%annotations)
{
    throws-like(
        {
            CATCH {
                when X::PDS::ParseError {
                    .source = source;
                    for %annotations -> \annotation {
                        .report.annotations.push(annotation);
                    }
                    .rethrow
                }
            }
            PDS::Grammar.new.fatal-error("boom", :$styles, :$source)
        },
        X::PDS::ParseError,
        source => source,
        report => { .annotations ~~ %annotations },
        message => / "At the start of the script" /,
        "exception information & annotations are propagated on rethrow",
    );
}

rethrow-ok();
rethrow-ok("my source");
rethrow-ok(:1year);
rethrow-ok("some source", :1year);
rethrow-ok(:1year, hello => "world");
rethrow-ok("some source", :1year, hello => "world");

done-testing;
