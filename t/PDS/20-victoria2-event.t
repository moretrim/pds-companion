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
use PDS::Victoria2;

my Styles:D     $styles        = Styles.new(Styles::never);
my Str:D        $source        = $?FILE;
my PDS::Grammar \event-grammar = PDS::Victoria2::Events;

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

        ai_chance = { factor = 3 }
    }
}
END
my \lines = pds-script.lines;

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

        option => [
            name => '"do the thing"',
            ai_chance => [ factor => 3 ],
        ],
    ]
];

is-deeply(
    PDS::soup(event-grammar, pds-script, :$styles, :$source),
    expectations,
    "can we parse a country event",
);

sub skip-initial-empty-lines(@lines) {
    @lines[(@lines.first(none(/ ^ \h* $ /), :k) // Empty) .. *]
}

subtest "error on event without id", {
    my \no-id = (
        |lines[0  ..^ 1],
        |lines[1 ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, no-id, :$styles, :$source)),
        "can we parse an event without an id",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Error,
                report => PDS::Report.new(
                    contexts => (0 => no-id.lines[0 ..^ 4].join("\n"),),
                    message => "country_event is missing a valid id entry",
                ),
            ),
        ),
        "error on event without an id",
    );
}

subtest "error on redundant id", {
    my $line = 1;
    my \script-with-dupe = (
        |lines[0     .. $line],
        |lines[$line .. *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, script-with-dupe, :$styles)),
        "can we parse an event with a redundant id",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Error,
                report => PDS::Report.new(
                    contexts => (
                        2 => script-with-dupe.lines[0 ..^ 5].join("\n"),
                        3 => script-with-dupe.lines[0 ..^ 6].join("\n"),
                    ),
                    message => "country_event has more than one id entry",
                ),
            ),
        ),
        "error on event with a redundant id",
    );
}

subtest "localisation on missing title", {
    my $line = 2;
    my \missing-title = (
        |lines[0      ..^ $line],
        |lines[$line ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, missing-title, :$styles)),
        "can we parse a country event with a missing title",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Missing-Localisation,
                report => PDS::Report.new(
                    contexts => (0 => missing-title.lines[0 ..^ 4].join("\n"),),
                    message => "country_event 18 is missing a valid title entry",
                ),
            ),
        ),
        "localisation on event with a missing title",
    );
}

subtest "localisation on missing desc", {
    my $line = 3;
    my \missing-desc = (
        |lines[0      ..^ $line],
        |lines[$line ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, missing-desc, :$styles)),
        "can we parse a country event with a missing desc",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Missing-Localisation,
                report => PDS::Report.new(
                    contexts => (0 => missing-desc.lines[0 ..^ 4].join("\n"),),
                    message => "country_event 18 is missing a valid desc entry",
                ),
            ),
        ),
        "localisation on event with a missing desc",
    );
}

subtest "opinion on redundant entries", {
    for (
        :2title, :3desc, :4picture, :5major,
        :7news, :8news_desc_long, :9news_desc_medium, :10news_desc_short,
        :12is_triggered_only,
    ) -> (:key($entry), :value($line)) {
        my \script-with-dupe = (
            |lines[0     .. $line],
            |lines[$line .. *],
        ).join("\n");

        ok(
            (my \parsed = PDS::parse(event-grammar, script-with-dupe, :$styles)),
            "can we parse a country event with a redundant $entry entry",
        );

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            ($line + 1) => skip-initial-empty-lines(
                                script-with-dupe.lines[(0 max $line - 2) ..^ $line + 4]
                            ).join("\n"),
                            ($line + 2) => skip-initial-empty-lines(
                                script-with-dupe.lines[(0 max $line - 1) ..^ $line + 5]
                            ).join("\n"),
                        ),
                        message => "country_event 18 has more than one $entry entry",
                    ),
                ),
            ),
            "opinion on event with redundant $entry entry",
        );
    }
}

subtest "opinion on major event with picture", {
    my \picture-major = (
        |lines[0   ..^ 5],
        "    major = yes",
        |lines[5  ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, picture-major, :$styles)),
        "can we parse a major country event with a picture",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Opinion,
                report => PDS::Report.new(
                    contexts => (
                        6 => picture-major.lines[3 ..^ 9].join("\n"),
                        5 => picture-major.lines[2 ..^ 8].join("\n"),
                    ),
                    message => "country_event 18 is major and has a picture (no picture is required for major events)"
                ),
            ),
        ),
        "opinion on major event with picture",
    );
}

subtest "info on event without a picture", {
    my \no-picture = (
        |lines[0   ..^ 4],
        |lines[4  ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, no-picture, :$styles)),
        "can we parse a country event without a picture",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Missing-Info,
                report => PDS::Report.new(
                    contexts => (
                        0 => no-picture.lines[0 ..^ 4].join("\n"),
                    ),
                    message => "country_event 18 is missing a picture"
                ),
            ),
        ),
        "info on event without a picture",
    );
}

subtest "info on missing news descriptions", {
    for (
        :8news_desc_long :9news_desc_medium :10news_desc_short
    ) -> (:key($desc), :value($line)) {
        my \missing-desc = (
            |lines[0      ..^ $line],
            |lines[$line ^..  *],
        ).join("\n");

        ok(
            (my \parsed = PDS::parse(event-grammar, missing-desc, :$styles)),
            "can we parse a newsworthy country event without $desc",
        );

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Missing-Info,
                    report => PDS::Report.new(
                        contexts => (
                            8 => missing-desc.lines[5 ..^ 11].join("\n"),
                        ),
                        message => qq:to«END».chomp,
                        country_event 18 is set to appear in the news, but is missing some news descriptions:
                            $desc
                        END
                    ),
                ),
            ),
            "info on newsworthy event without $desc",
        );
    }
}

subtest "opinion on redundant news descriptions", {
    for (
        :8news_desc_long :9news_desc_medium :10news_desc_short
    ) -> (:key($desc), :value($line)) {
        my \missing-desc = (
            |lines[0      ..^ 7],
            "    news = no",
            |lines[7     ^..^ $line],
            |lines[$line ^..  *],
        ).join("\n");

        ok(
            (my \parsed = PDS::parse(event-grammar, missing-desc, :$styles)),
            "can we parse a non-newsworthy country event with redundant $desc",
        );

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            8 => skip-initial-empty-lines(
                                missing-desc.lines[5 ..^ 11]
                            ).join("\n"),
                            9 => skip-initial-empty-lines(
                                missing-desc.lines[6 ..^ 12]
                            ).join("\n"),
                            10 => skip-initial-empty-lines(
                                missing-desc.lines[7 ..^ 13]
                            ).join("\n"),
                        ),
                        message => qq:to«END».chomp,
                        country_event 18 is set not to appear in the news, but has news descriptions
                        END
                    ),
                ),
            ),
            "opinion on non-newsworthy event with redundant $desc",
        );
    }
}

subtest "opinion on triggered-only event with redundant entries", {
    for (
        Q[    mean_time_to_happen = { days = 3 }],
        Q[    trigger = { tag = ENG }],
    ).combinations.skip(1).pairs -> (:key($which), :value($extras)) {
        my \triggered-only-with-extras = (
            |lines[0  ..^ 13],
            |$extras,
            |lines[13 ..  *],
        ).join("\n");

        my @extras = $extras.map(*.words[0]);

        ok(
            (my \parsed = PDS::parse(event-grammar, triggered-only-with-extras, :$styles, :$source)),
            "can we parse a triggered-only event with redundant entries (step $which: @extras.join(", "))",
        );

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            13 => triggered-only-with-extras.lines[10 ..^ 16].join("\n"),
                            14 => skip-initial-empty-lines(
                                triggered-only-with-extras.lines[11 ..^ 17]
                            ).join("\n"),
                            (15 => triggered-only-with-extras.lines[12 ..^ 18].join("\n") if $which == 2),
                        ),
                        message => qq:to«END».chomp,
                        country_event 18 is triggered only, but has redundant entries:
                            @extras.join(", ")
                        (Ignoring on-action events not yet implemented.)
                        END
                    ),
                ),
            ),
            "opinion on triggered-only event with redundant entries (step $which: @extras.join(", "))",
        );
    }
}

subtest "opinion on event without a trigger", {
    for (
        Q[    is_triggered_only = no
        ],
        Q[    mean_time_to_happen = { days = 3 }
        ],
    ).combinations.pairs -> (:key($which), :value($extras)) {
        my \no-trigger = (
            |lines[0   ..^ 12],
            |$extras,
            |lines[12 ^..  *],
        ).join("\n");

        my @extras = $extras.map(*.words[0]);

        ok(
            (my \parsed = PDS::parse(event-grammar, no-trigger, :$styles, :$source)),
            "can we parse an event without a trigger (step $which: @extras.join(", "))",
        );

        my \with-is_triggered_only   = (1, 3);
        my \with-mean_time_to_happen = (2, 3);
        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            (0 => no-trigger.lines[0 ..^ 4].join("\n") if $which !∈ with-is_triggered_only),
                            (13 => no-trigger.lines[10 ..^ 16].join("\n") if $which ∈ with-is_triggered_only),
                        ),
                        message => qq:to«END».chomp,
                        country_event 18 has no trigger. Either:
                        • add a trigger, if the event is intended to activate by itself
                        • set the following, if the event is only ever activated by e.g. other events or decisions:
                            ｢is_triggered_only = yes｣
                        END
                    ),
                ),

                (PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            (13 => no-trigger.lines[10 ..^ 16].join("\n") if $which != 3),
                            (15 => no-trigger.lines[12 ..^ 18].join("\n") if $which == 3),
                        ),
                        message => "country_event 18 has a mean_time_to_happen but no trigger",
                    ),
                ) if $which ∈ with-mean_time_to_happen),
            ),
            "opinion on event without a trigger (step $which: @extras.join(", "))",
        );
    }
}

subtest "error on event without option", {
    my \no-option = (
        |lines[0  ..^ 14],
        |lines[19 ..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, no-option, :$styles, :$source)),
        "can we parse an event without an option",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Error,
                report => PDS::Report.new(
                    contexts => (0 => no-option.lines[0 ..^ 4].join("\n"),),
                    message => "country_event 18 is missing a valid option entry",
                ),
            ),
        ),
        "error on event without an option",
    );
}

subtest "localisation on event option without name", {
    my \no-name = (
        |lines[0   ..^ 15],
        |lines[15 ^..  *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, no-name, :$styles, :$source)),
        "can we parse an event without an option name",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Missing-Localisation,
                report => PDS::Report.new(
                    contexts => (15 => no-name.lines[12 ..^ 18].join("\n"),),
                    message => "an option of country_event 18 is missing a valid name entry",
                ),
            ),
        ),
        "localisation on event without an option name",
    );
}

subtest "opinion on event option with redundant name", {
    my \extra-name = (
        |lines[0   .. 15],
         lines[15],
        |lines[15 ^.. *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, extra-name, :$styles, :$source)),
        "can we parse an event with a redundant option name",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Opinion,
                report => PDS::Report.new(
                    contexts => (
                        16 => skip-initial-empty-lines(extra-name.lines[13 ..^ 19]).join("\n"),
                        17 => skip-initial-empty-lines(extra-name.lines[14 ..^ 20]).join("\n"),
                    ),
                    message => "an option of country_event 18 has more than one name entry",
                ),
            ),
        ),
        "opinion on event with a redundant option name",
    );
}

subtest "opinion on event option with redundant ai_chance", {
    my \extra-ai-chance = (
        |lines[0   .. 17],
         lines[17],
        |lines[17 ^.. *],
    ).join("\n");

    ok(
        (my \parsed = PDS::parse(event-grammar, extra-ai-chance, :$styles, :$source)),
        "can we parse an event with a redundant option ai_chance",
    );

    cmp-ok(
        parsed.made<REMARKS>.unique,
        &PDS::eqv-remarks,
        (
            PDS::Remark.new(
                kind => PDS::Remark::Opinion,
                report => PDS::Report.new(
                    contexts => (
                        18 => skip-initial-empty-lines(extra-ai-chance.lines[15 ..^ 21]).join("\n"),
                        19 => skip-initial-empty-lines(extra-ai-chance.lines[16 ..^ 21]).join("\n"),
                    ),
                    message => "an option of country_event 18 has more than one ai_chance entry",
                ),
            ),
        ),
        "opinion on event with a redundant option ai_chance",
    );
}

done-testing;
