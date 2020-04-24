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

my Styles:D $styles = Styles.new(Styles::never);
my PDS::Grammar:D \test-grammar = PDS::Unstructured.new(source => $?FILE);

use lib 't';
use resources::vic2-model-country-history00;

my \expectations = [
    capital => 1167,
    primary_culture => 'bedouin',
    religion => 'sunni',
    government => 'absolute_monarchy',
    plurality => 0.0,
    nationalvalue => 'nv_tradition',
    literacy => 0.01,
    non_state_culture_literacy => 0.01,

    # Political reforms
    slavery => 'yes_slavery',
    upper_house_composition => 'appointed',
    vote_franschise => 'none_voting',
    public_meetings => 'no_meeting',
    press_rights => 'state_press',
    trade_unions => 'no_trade_unions',
    voting_system => 'jefferson_method',
    political_parties => 'underground_parties',

    # Social Reforms
    wage_reform => 'no_minimum_wage',
    work_hours => 'no_work_hour_limit',
    safety_regulations => 'no_safety',
    health_care => 'no_health_care',
    unemployment_subsidies => 'no_subsidies',
    pensions => 'no_pensions',
    school_reforms => 'no_schools',

    # New Reforms
    conscription => 'one_year_draft',
    debt_law => 'peonage',
    penal_system => 'capital_punishment',
    child_labor => 'child_labor_legal',
    citizens_rights => 'primary_culture_only',
    border_policy => 'open_borders',

    ruling_party => 'ABU_conservative',
    upper_house => [
        fascist => 0,
        liberal => 10,
        conservative => 75,
        reactionary => 15,
        anarcho_liberal => 0,
        socialist => 0,
        communist => 0,
    ],

    set_country_flag => 'sunni_country',

    govt_flag => [
        government => 'absolute_monarchy',
        flag => 'theocracy',
    ],

    # Technologies
    flintlock_rifles => 1,

    # Inventions
    :small_arms_production,
    :ammunition_production,
    #:big_sail_ships,
    #:sail_ships_transport,
    #:big_sail_support,

    # Starting Consciousness
    consciousness => 0,
    nonstate_consciousness => 0,

    oob => '"ABU_oob.txt"',
    '1861.1.1' => [
        oob => '"/1861/ABU_oob.txt"',
        foreign_weapons => 'yes_foreign_weapons',

        # Technologies
        flintlock_rifles => 1,
    ],
];

is-deeply
    soup(PDS::Unstructured, vic2-model-country-history00::resource, :$styles),
    expectations,
    "can we parse a representative country history file";

done-testing;
