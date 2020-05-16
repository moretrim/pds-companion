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

my Styles:D     $styles       = Styles.new(Styles::never);
my Str:D        $source       = $?FILE;
my PDS::Grammar \test-grammar = PDS::Victoria2::Events;
my PDS::Grammar \cb-grammar   = PDS::Victoria2::CasusBelli;

use lib 't/resources';
use vic2-hpm-cb_types;

my %universe = PDS::parse(cb-grammar, vic2-hpm-cb_types::resource, :$styles).made<RESULT>;

sub effects(Str:D $_ --> Str:D) {
    qq:to«END».chomp
    country_event = \{
        id      = 3
        title   = "mock event to parse effects"
        desc    = "mock description"
        picture = "mock picture"

        is_triggered_only = yes

        option = \{
            name = "mock option"

    $_.indent(4*2)
        \}
    \}
    END
}

my \plain-wars = effects(Q:to«END»);
# tag targets

war = PER

war = {
    target = JAP
    attacker_goal = {
        casus_belli = annex
    }
}

# keyword targets

war = FROM

war = {
    target = THIS
    attacker_goal = {
        casus_belli = humiliate
    }
}

# other entries

war = {
    target = SWI

    call_ally = no

    attacker_goal = {
        casus_belli = annex
    }
}

war = {
    target = FRA

    call_ally = yes

    attacker_goal = {
        casus_belli = annex
    }
}

war = {
    target = ENG

    call_ally = yes

    attacker_goal = {
        casus_belli = humiliate
    }

    attacker_goal = {
        casus_belli = acquire_any_state
        state_province_id = 1485
    }

    defender_goal = {
        casus_belli = annex
        country = THIS
    }

    defender_goal = {
        casus_belli = cut_down_to_size
    }
}
END

my \expectations = [
    country_event => [
        id      => 3,
        title   => "\"mock event to parse effects\"",
        desc    => "\"mock description\"",
        picture => "\"mock picture\"",

        :is_triggered_only,

        option => [
            name => "\"mock option\"",

            war => "PER",

            war => [
                target => "JAP",

                attacker_goal => [
                    casus_belli => "annex"
                ],
            ],

            war => "FROM",

            war => [
                target => "THIS",

                attacker_goal => [
                    casus_belli => "humiliate",
                ],
            ],

            war => [
                target => "SWI",

                :!call_ally,

                attacker_goal => [
                    casus_belli => "annex",
                ],
            ],

            war => [
                target => "FRA",

                :call_ally,

                attacker_goal => [
                    casus_belli => "annex",
                ],
            ],

            war => [
                target => "ENG",

                :call_ally,

                attacker_goal => [
                    casus_belli => "humiliate",
                ],

                attacker_goal => [
                    casus_belli => "acquire_any_state",
                    state_province_id => 1485,
                ],

                defender_goal => [
                    casus_belli => "annex",
                    country => "THIS",
                ],

                defender_goal => [
                    casus_belli => "cut_down_to_size",
                ],
            ],
        ],
    ],
];

is-deeply(
    PDS::soup(test-grammar, plain-wars, :$styles, :$source),
    expectations,
    "can we parse the input",
);

sub parse-ok(\input, \msg) {
    ok(
        (my \parsed = PDS::parse(test-grammar, input, :$styles, :$source, :%universe)),
        msg,
    );

    parsed && nok(
        parsed.made<INCOMPLETE-UNIVERSE>,
        "bootstrapping the event grammar with the result of the casus belli grammar failed",
    );

    parsed
}

sub skip-initial-empty-lines(@lines) {
    @lines[(@lines.first(none(/ ^ \h* $ /), :k) // Empty) .. *]
}

subtest "conventions on Call to Arms wars", {
    {
        my \call-to-arms = effects(Q:to«END».chomp);
        war = {
            target = AA0
            attacker_goal = {
                casus_belli = call_allies_cb
            }
        }
        END

        my \parsed = parse-ok(call-to-arms, "can we parse a Call to Arms war (case 0: target)");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            13 => skip-initial-empty-lines(call-to-arms.lines[11 ..^ 16]).join("\n"),
                            15 => skip-initial-empty-lines(call-to-arms.lines[12 ..^ 18]).join("\n"),
                        ),
                        message => "target is unnecessary when starting a Call to Arms war",
                    ),
                ),

                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            12 => skip-initial-empty-lines(call-to-arms.lines[9 ..^ 15]).join("\n"),
                            15 => skip-initial-empty-lines(call-to-arms.lines[12 ..^ 18]).join("\n"),
                        ),
                        message => "Call to Arms war is missing a valid call_ally entry (｢call_ally = yes｣ was expected)",
                    ),
                ),
            ),
            "convention on Call to Arms war (case 0: target)",
        );
    }

    {
        my \call-to-arms = effects(Q:to«END».chomp);
        war = {
            call_ally = yes
            attacker_goal = {
                casus_belli = call_allies_cb
            }
        }
        END

        my \parsed = parse-ok(call-to-arms, "can we parse a Call to Arms war (case 1: call_ally = yes)");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            13 => skip-initial-empty-lines(call-to-arms.lines[10 ..^ 16]).join("\n"),
                        ),
                        message => "call_ally entry of Call to Arms war set to no when yes was expected",
                    ),
                ),
            ),
            "convention on Call to Arms war (case 1: call_ally = yes)",
        );
    }

    {
        my \call-to-arms = effects(Q:to«END».chomp);
        war = {
            target = AA2
            call_ally = yes
            attacker_goal = {
                casus_belli = call_allies_cb
            }
        }
        END

        my \parsed = parse-ok(call-to-arms, "can we parse a Call to Arms war (case 2: target, call_ally = yes)");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            13 => skip-initial-empty-lines(call-to-arms.lines[11 ..^ 16]).join("\n"),
                            16 => skip-initial-empty-lines(call-to-arms.lines[13 ..^ 19]).join("\n"),
                        ),
                        message => "target is unnecessary when starting a Call to Arms war",
                    ),
                ),

                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            14 => skip-initial-empty-lines(call-to-arms.lines[11 ..^ 17]).join("\n"),
                        ),
                        message => "call_ally entry of Call to Arms war set to no when yes was expected",
                    ),
                ),
            ),
            "convention on Call to Arms war (case 2: target, call_ally = yes)",
        );
    }

    {
        my \call-to-arms = effects(Q:to«END».chomp);
        war = {
            call_ally = no
            attacker_goal = {
                casus_belli = call_allies_cb
            }
        }
        END

        my \parsed = parse-ok(call-to-arms, "can we parse a Call to Arms war (case 3: call_ally = no)");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            13 => skip-initial-empty-lines(call-to-arms.lines[10 ..^ 16]).join("\n"),
                        ),
                        message => "call_ally entry of Call to Arms war set to no when yes was expected",
                    ),
                ),
            ),
            "convention on Call to Arms war (case 3: call_ally = no)",
        );
    }

    {
        my \call-to-arms = effects(Q:to«END».chomp);
        war = {
            target = AA0
            call_ally = no
            attacker_goal = {
                casus_belli = call_allies_cb
            }
        }
        END

        my \parsed = parse-ok(call-to-arms, "can we parse a Call to Arms war (case 4: target, call_ally = no)");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            13 => skip-initial-empty-lines(call-to-arms.lines[11 ..^ 16]).join("\n"),
                            16 => skip-initial-empty-lines(call-to-arms.lines[13 ..^ 19]).join("\n"),
                        ),
                        message => "target is unnecessary when starting a Call to Arms war",
                    ),
                ),

                PDS::Remark.new(
                    kind => PDS::Remark::Convention,
                    report => PDS::Report.new(
                        contexts => (
                            14 => skip-initial-empty-lines(call-to-arms.lines[11 ..^ 17]).join("\n"),
                        ),
                        message => "call_ally entry of Call to Arms war set to no when yes was expected",
                    ),
                ),
            ),
            "convention on Call to Arms war (case 4: target), call_ally = no",
        );
    }
}

subtest "opinions", {
    {
        my \lone-target = effects(Q:to«END».chomp);
        war = {
            target = from
        }
        END

        my \parsed = parse-ok(lone-target, "can we parse a lone target war");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Opinion,
                    report => PDS::Report.new(
                        contexts => (
                            12 => skip-initial-empty-lines(lone-target.lines[9 ..^ 16]).join("\n"),
                        ),
                        message => qq:to«END».chomp,
                        This CB-less war in block form can use the tag form instead:
                                    war = from
                        (Did you mean for this war to call allies? If so, use: ｢call_ally = yes｣)
                        END
                    ),
                ),
            ),
            "opinion on lone target war",
        );
    }
}

subtest "error on unrecognised casus belli", {
    {
        my \unrecognised-cb = effects(Q:to«END».chomp);
        war = {
            target = xxx
            attacker_goal = { casus_belli = my_cb }
            defender_goal = { casus_belli = my_cb }
        }
        END

        my \parsed = parse-ok(unrecognised-cb, "can we parse an unrecognised CB war");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Error,
                    report => PDS::Report.new(
                        contexts => (
                            14 => skip-initial-empty-lines(unrecognised-cb.lines[11 ..^ 17]).join("\n"),
                        ),
                        message => "Casus belli not recognised",
                    ),
                ),

                PDS::Remark.new(
                    kind => PDS::Remark::Error,
                    report => PDS::Report.new(
                        contexts => (
                            15 => skip-initial-empty-lines(unrecognised-cb.lines[12 ..^ 18]).join("\n"),
                        ),
                        message => "Casus belli not recognised",
                    ),
                ),
            ),
            "error on unrecognised CB war",
        );
    }
}

subtest "quirk on naked CB", {
    {
        my \naked-cb = effects(Q:to«END».chomp);
        war = {
            target = xxx
            attacker_goal = { casus_belli = humiliate }
        }
        END

        my \parsed = parse-ok(naked-cb, "can we parse a naked CB war");

        cmp-ok(
            parsed.made<REMARKS>.unique,
            &PDS::eqv-remarks,
            (
                PDS::Remark.new(
                    kind => PDS::Remark::Quirk,
                    report => PDS::Report.new(
                        contexts => (
                            14 => skip-initial-empty-lines(naked-cb.lines[11 ..^ 17]).join("\n"),
                        ),
                        message => qq:to«END».chomp,
                        $styles.header("CB was not granted to the attacker prior to starting war")

                        The game makes the attacker of the war (but not its defender) pay the infamy costs of all CBs
                        that are not currently on hand. This is hidden from the player.

                        Consider separately granting the CB to the attacker just prior, together with an explicit infamy cost:
                            badboy = 3 # pick any amount of your choice that feels fair,
                                       # or remove if the war should cost no infamy

                            casus_belli = \{
                                target = xxx
                                type = humiliate
                                months = 24
                            \}
                        This is fair to the player when done this way. In-game tooltips will properly display the infamy
                        cost (if any) of the war.
                        END
                    ),
                ),
            ),
            "quirk on naked CB war",
        );
    }
}

done-testing;
