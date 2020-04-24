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
my PDS::Grammar \event-grammar = PDS::Victoria2::Events.new(source => $?FILE);

my \pds-script = q:to«END»;
country_event = {
    id = 18
    title = "EVTNAME00018"
    desc = "EVTDESC00018"
    picture = "ships"
    major = no

    news = yes
    news_desc_long   = "EVTDESC00018_NEWS_LONG"
    news_desc_medium = "EVTDESC00018_NEWS_MEDIUM"
    news_desc_short  = "EVTDESC00018_NEWS_SHORT"

    is_triggered_only = yes

    option = {
        name = "do the thing"
    }
}
END

my \expectations = [
    country_event => [
        id => 18,
        title => '"EVTNAME00018"',
        desc => '"EVTDESC00018"',
        picture => '"ships"',
        :!major,

        :news,
        news_desc_long => '"EVTDESC00018_NEWS_LONG"',
        news_desc_medium => '"EVTDESC00018_NEWS_MEDIUM"',
        news_desc_short => '"EVTDESC00018_NEWS_SHORT"',

        :is_triggered_only,

        option => [ name => '"do the thing"' ],
    ]
];

is-deeply
    soup(event-grammar, pds-script, :$styles),
    expectations,
    "can we parse a country event";

subtest "reject malformed events", {
    # skip id on line 1
    my \no-id = pds-script.lines[0..^1, 1^..*].flat.join("\n");

    throws-like
        { soup(event-grammar, no-id, :$styles) },
        X::PDS::ParseError,
        message =>
            / "Error while parsing ‘<string>’ at line 17:" /
            & / "event is missing an ID" /,
        "no event id provided to country event";
}

subtest "remark on major events with pictures", {
    # picture + major
    my \picture-major = (
        |pds-script.lines[^5],
        "    major = yes",
        |pds-script.lines[6..*],
    ).flat.join("\n");

    my \parsed = PDS::parse(event-grammar, picture-major, :$styles);
    is ?parsed, True, "can we parse a major country event with a picture";
    is-deeply parsed.made<REMARKS>.unique, (
        PDS::Remark.new(
            line => 6,
            kinds => set(PDS::Remark::Opinion),
            message=> "event 18 is major and has a picture (no picture is required for major events)"
        ),
    );
}

done-testing;
