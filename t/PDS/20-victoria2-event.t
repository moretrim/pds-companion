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
use PDS::Victoria2;

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

is-deeply soup(event-grammar, pds-script), expectations, "can we parse a country event";

subtest "reject malformed events", {
    # skip id on line 1
    my \no-id = pds-script.lines[0..^1, 1^..*].flat.join("\n");

    throws-like
        { soup(event-grammar, no-id) },
        X::PDS::ParseError,
        message =>
            / "Cannot parse input: event is missing an ID" /
            & / "at line 17" /,
        "no event id provided to country event";
}

# use lib 't/resources';
# use resource-mod;

# is-deeply soup(PDS::Grammar, resource-mod::resource), expectations;

done-testing;