=begin COPYRIGHT
Copyright © 2019–2021 moretrim.

This file is part of pds-companion.

pds-companion is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 3 as
published by the Free Software Foundation.

pds-companion is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with pds-companion.  If not, see <https://www.gnu.org/licenses/gpl-3.0.html>.
=end COPYRIGHT

#| Tools for Victoria 2 PDS script files.
unit module PDS::Victoria2;

use PDS::remake;
use PDS :ast;
use PDS::Styles;

constant Remark = PDS::Remark;

module hardcoded {

our constant peace-option-to-define = %(
    po_annex                        => "INFAMY_ANNEX",
    po_demand_state                 => "INFAMY_DEMAND_STATE",
    po_add_to_sphere                => "INFAMY_ADD_TO_SPHERE",
    po_disarmament                  => "INFAMY_DISARMAMENT",
    po_reparations                  => "INFAMY_REPARATIONS",
    po_destroy_forts                => "INFAMY_DESTROY_FORTS",
    po_destroy_naval_bases          => "INFAMY_DESTROY_NAVAL_BASES",
    po_transfer_provinces           => "INFAMY_TRANSFER_PROVINCES",
    po_remove_prestige              => "INFAMY_PRESTIGE",
    po_make_puppet                  => "INFAMY_MAKE_PUPPET",
    # N.b. somewhat speculative
    po_clear_union_sphere           => "INFAMY_CONCEDE",
    po_release_puppet               => "INFAMY_RELEASE_PUPPET",
    po_status_quo                   => "INFAMY_STATUS_QUO",
    po_install_communist_gov_type   => "INFAMY_INSTALL_COMMUNIST_GOV_TYPE",
    po_uninstall_communist_gov_type => "INFAMY_UNINSTALL_COMMUNIST_GOV_TYPE",
    po_remove_cores                 => "INFAMY_REMOVE_CORES",
    po_colony                       => "INFAMY_COLONY",
);

our constant infamy-costs = %(
    # copied from HPM/HFM defines
    INFAMY_ADD_TO_SPHERE                => 2,
    INFAMY_RELEASE_PUPPET               => 0.5,
    INFAMY_MAKE_PUPPET                  => 5,
    INFAMY_DISARMAMENT                  => 5,
    INFAMY_DESTROY_FORTS                => 2,
    INFAMY_DESTROY_NAVAL_BASES          => 2,
    INFAMY_REPARATIONS                  => 5,
    INFAMY_TRANSFER_PROVINCES           => 5,
    INFAMY_REMOVE_CORES                 => 0,
    INFAMY_PRESTIGE                     => 2,
    INFAMY_CONCEDE                      => 1,
    INFAMY_STATUS_QUO                   => 0,
    INFAMY_ANNEX                        => 10,
    INFAMY_DEMAND_STATE                 => 5,
    INFAMY_INSTALL_COMMUNIST_GOV_TYPE   => 5,
    INFAMY_UNINSTALL_COMMUNIST_GOV_TYPE => 5,
    INFAMY_COLONY                       => 0,
);

} # hardcoded

#| Base for common items for Victoria 2 grammars.
our grammar Base is PDS::Structured {
    ## Tokens

    token casus-belli { <soup=.text> }

    ## Triggers

    rule trigger {
        | $<soup=ai>=(<key=.kw('ai')> '=' <value=.yes-or-no>)

        # catch-all
        | $<soup>=(<key=.simplex> '=' [<value=.simplex>|<value=trigger-block>])
    }

    rule trigger-block {
        '{' ~ '}' <entries=.trigger>*
    }

    ## Effects

    rule effect(::?CLASS:D \group) {
        | <soup=add_country_modifier>
        | <soup=add_province_modifier>
        | <soup=country-event-effect>
        | <soup=province-event-effect>
        | <soup=casus-belli-effect>
        | <soup=war-effect(group)>

        # catch-all
        | $<soup>=(<key=.simplex> '=' [<value=.simplex>|<value=effect-block(group)>])
    }

    rule effect-block(::?CLASS $group?) {
        '{' ~ '}' [ {} <entries=effects=.effect($group // $/)> ]*
    }

    rule add_country_modifier  {
        <key=.kw("add_country_modifier")> '=' <value=.name-duration-block>
        {} <.validate-modifier>
    }
    rule add_province_modifier {
        <key=.kw("add_province_modifier")> '=' <value=.name-duration-block>
        {} <.validate-modifier>
    }

    rule name-duration-block {
        '{' ~ '}' [
            [
                @<entries=name>     = (<key=.kw('name')>     '=' <value=.text>)
                @<entries=duration> = (<key=.kw('duration')> '=' <value=.number>)
            ] | [
                @<entries=duration> = (<key=.kw('duration')> '=' <value=.number>)
                @<entries=name>     = (<key=.kw('name')>     '=' <value=.text>)
            ]
        ]
    }

    method validate-modifier {
        # TODO verify modifier name

        $.ok
    }

    rule country-event-effect  { <key=.kw('country_event')>  '=' <value=.event-effect-target> }
    rule province-event-effect { <key=.kw('province_event')> '=' <value=.event-effect-target> }

    rule event-effect-target {
        <soup=.number>
        | '{' ~ '}' [
            [
                @<entries=id>   = (<key=.kw('id')>   '=' <value=.number>)
                @<entries=days> = (<key=.kw('days')> '=' <value=.number>)
            ] | [
                @<entries=days> = (<key=.kw('days')> '=' <value=.number>)
                @<entries=id>   = (<key=.kw('id')>   '=' <value=.number>)
            ]
        ]
    }

    rule casus-belli-effect {
        <key=.kw('casus_belli')> '=' <value=.casus-belli-block>
        {} <.validate-casus-belli>
    }

    rule casus-belli-block {
        '{' ~ '}' [
            | @<entries=target> = (<key=.kw('target')> '=' <value=.tag-reference>)
            | @<entries=type>   = (<key=.kw('type')>   '=' <value=.casus-belli>)
            | @<entries=months> = (<key=.kw('months')> '=' <value=.number>)
        ]*
    }

    method validate-casus-belli {
        my (\casus-belli, \casus-belli-block) = self<key value>;

        given casus-belli-block {
            .expect-one(casus-belli, "target");
            .expect-one(casus-belli, "type");
            .expect-one(casus-belli, "months");
        }

        $.ok
    }

    rule war-effect(::?CLASS:D \group) {
        <key=.kw('war')> '=' [
            | <value=war-effect-block>
            | <value=war-tag-reference=.tag-reference>
        ]
        {} <.validate-war(group)>
    }

    rule war-effect-block {
        '{' ~ '}' [
            | @<entries=target>                  = (<key=.kw('target')>        '=' <value=.tag-reference>)
            | @<entries=wargoals=attacker-goals> = (<key=.kw('attacker_goal')> '=' <value=.wargoal-block>)
            | @<entries=wargoals=defender-goals> = (<key=.kw('defender_goal')> '=' <value=.wargoal-block>)
            | @<entries=call_ally>               = (<key=.kw('call_ally')>     '=' <value=.yes-or-no>)
        ]*
    }

    rule wargoal-block {
        '{' ~ '}' [
            | @<entries=casus_belli>       = (<key=.kw('casus_belli')>       '=' <value=.casus-belli>)
            | @<entries=state_province_id> = (<key=.kw('state_province_id')> '=' <value=.integer>)
            | @<entries=country>           = (<key=.kw('country')>           '=' <value=.tag-reference>)
        ]*
    }

    method validate-war(::?CLASS:D \group) {
        my (\war, \war-block) = self<key war-effect-block>;

        with war-block {
            # TODO: hardcoding of the CB
            if any(.<attacker-goals>)<value><casus_belli>[0]<value>.&kw eq "call_allies_cb".fc {
                my @extra-locs =
                    .<attacker-goals>
                    .map({ .<value><casus_belli>[0]<value> })
                    .grep({ .&kw eq "call_allies_cb".fc })
                    .sort(*.pos);

                my $element = "Call to Arms $*STYLES.code(war.Str)";
                .prefer-none(war, "target", :@extra-locs, too-many => Remark::Convention => -> **@ { qq:to«END» });
                target is unnecessary when starting a $element
                END

                .prefer-yes((.<call_ally><key> // war), "call_ally", Remark::Convention, :@extra-locs, :$element);
            } else {
                if my \target = .expect-one(war, "target") {
                    if .<wargoals>.elems == 0 && .<call_ally>[0].&no {
                        my \before    = $*STYLES.code(self.preceding);
                        my \tag-form  = $*STYLES.code-highlight("war = $*STYLES.code-focus(target<value>.Str)");
                        my \call-ally = $*STYLES.code-quote("call_ally = $*STYLES.code-focus("yes")");
                        self.opinion(qq:to«END».chomp);
                        This CB-less war in block form can use the tag form instead:
                        {"{before}{tag-form}".indent(4)}
                        (Did you mean for this war to call allies? If so, use: {call-ally})
                        END
                    }
                }
            }

            .prefer-at-most-one(war, "call_ally");

            if %*UNIVERSE<casus-belli>:exists {
                my \casus-belli = %*UNIVERSE<casus-belli>.Map;

                # War makes the attacker (but not the defender) pay the infamy costs of their CBs. Conventionally, modders
                # should.
                my %nearby-casus-belli = group<effects>.map({
                    .<casus-belli-effect><value><type>[0]<value>:v
                }).flat.map(&kw).Set;

                for .<wargoals> {
                    my \kind = .<key>.&kw;
                    with .<value>.prefer-one(.<key>, "casus_belli") {
                        my \cb = .<value>;
                        if cb.&kw !∈ casus-belli.keys.Set {
                            cb.error(qq:to«END».chomp)
                            Casus belli not recognised
                            END
                        } else {
                            my \cb-info = casus-belli{cb.&kw};

                            sub cb-infamy-cost(Associative \cb-info --> Rat){
                                my \factor  = cb-info<badboy_factor>;
                                my \options = cb-info<options>;
                                factor * [+] options.map(-> \option {
                                    hardcoded::peace-option-to-define{option}
                                    andthen hardcoded::infamy-costs{$_}
                                    orelse do {
                                        cb.error(qq:to«END».chomp);
                                        $*STYLES.alert("$*PROGRAM-NAME internal error") (This is not your or the mod’s fault.)
                                        Casus belli has unrecognised peace option cost: $*STYLES.code(option.Str)
                                        END
                                        1 #`(non-null infamy to be noisy by default)
                                    }
                                })
                            }

                            my \infamy = cb-infamy-cost(cb-info);

                            unless
                                # defender doesn’t pay infamy cost
                                kind eq "defender_goal".fc
                                # CB is always active, never fabricated
                                || cb-info<always>
                                # CB was granted prior
                                || .<value>.&kw ∈ %nearby-casus-belli
                                || infamy == 0
                            {
                                my $alignment = " " x infamy.Str.chars;
                                .quirk(qq:to«END».chomp);
                                $*STYLES.header("CB was not granted to the attacker prior to starting war")

                                The game makes the attacker of the war (but not its defender) pay the infamy costs of all CBs
                                that are not currently on hand. This is hidden from the player.

                                Consider separately granting the CB to the attacker just prior, together with an explicit infamy cost:
                                {
                                    $*STYLES.code(qq:to«END»).chomp.indent(4)
                                    badboy = $*STYLES.code-focus(infamy.Str)$*STYLES.code(" # actual infamy amount,")
                                             $alignment # or pick any amount of your choice that feels fair,
                                             $alignment # or remove if the war should cost no infamy

                                    casus_belli = \{
                                        target = {war-block<target>[0]<value> andthen .Str orelse $*STYLES.code-highlight("<war lacks a target>")}
                                        type = $*STYLES.code-focus(.<value>.Str)
                                        months = 24
                                    \}
                                    END
                                }
                                This is fair to the player when done this way. In-game tooltips will properly display the infamy
                                cost (if any) of the war.
                                END
                            }
                        }
                    }
                    .<value>.prefer-at-most-one(.<key>, "state_province_id");
                    .<value>.prefer-at-most-one(.<key>, "country");
                }
            }
        }

        $.ok
    }
}

our sub event-effect-id(\ast where Any:U|Match --> Int) is export(:ast)
{
    pair(ast)
    && ast<key>.&kw ~~ ('country_event', 'province_event').any.fc
    && ast<value>.&{ .<soup>, .<id>[0]<value> }.grep(*.defined)[0]
    andthen .Int orelse Int
}

#| Parse a C<cb_types.txt> file.
our grammar CasusBelli is Base {
    method topo-level { 0 }
    method where      { <common> }
    method what       { "cb_types.txt" }
    method descr      { "common/cb_types.txt file" }

    rule TOP(Styles:D :$styles!, Str :$source, :%universe = %()) {
        :my $*STYLES   = $styles;
        :my $*SOURCE   = $source;
        :my %*UNIVERSE = %universe;
        :my @*REMARKS;

        ^ [
            | <peace_order>
            | <entries=casus-belli-definitions=.casus-belli-definition>
        ]* $

        {
            remake(
                $/,
                REMARKS => @*REMARKS,
                RESULT  => casus-belli => @<entries>.map({
                    .<key>.&kw => do %(
                        do given .<value> {
                            badboy_factor => .<badboy_factor>[0].&{ .<value>.?Rat // 0 },
                            (:always if .<always>[0].&yes),
                            options => .<options>.map(*<key>.Str).List,
                        }
                    )
                }).List,
            )
        } <.validate-casus-belli-file>
    }

    rule peace_order {
        <key=.kw('peace_order')> '=' $<value>=('{' ~ '}' [ <entries=.casus-belli> ]*)
    }

    rule casus-belli-definition {
        <key=.text> '=' <value=.casus-belli-block>
        {} <.validate-casus-belli>
    }

    rule casus-belli-block {
        '{' ~ '}' [
            | @<entries=sprite_index>         = (<key=.kw('sprite_index')>         '=' <value=.number>)
            | @<entries=is_triggered_only>    = (<key=.kw('is_triggered_only')>    '=' <value=.yes-or-no>)
            | @<entries=months>               = (<key=.kw('months')>               '=' <value=.number>)
            | @<entries=crisis>               = (<key=.kw('crisis')>               '=' <value=.yes-or-no>)
            | @<entries=construction_speed>   = (<key=.kw('construction_speed')>   '=' <value=.number>)
            | @<entries=constructing_cb>      = (<key=.kw('constructing_cb')>      '=' <value=.yes-or-no>)
            | @<entries=great_war_obligatory> = (<key=.kw('great_war_obligatory')> '=' <value=.yes-or-no>)

            | @<entries=badboy_factor>     = (<key=.kw('badboy_factor')>     '=' <value=.number>)
            | @<entries=prestige_factor>   = (<key=.kw('prestige_factor')>   '=' <value=.number>)
            | @<entries=peace_cost_factor> = (<key=.kw('peace_cost_factor')> '=' <value=.number>)
            | @<entries=penalty_factor>    = (<key=.kw('penalty_factor')>    '=' <value=.number>)
            | @<entries=always>            = (<key=.kw('always')>            '=' <value=.yes-or-no>)
            | @<entries=is_civil_war>      = (<key=.kw('is_civil_war')>      '=' <value=.yes-or-no>)

            | @<entries=break_truce_prestige_factor>  = (<key=.kw('break_truce_prestige_factor')>  '=' <value=.number>)
            | @<entries=break_truce_infamy_factor>    = (<key=.kw('break_truce_infamy_factor')>    '=' <value=.number>)
            | @<entries=break_truce_militancy_factor> = (<key=.kw('break_truce_militancy_factor')> '=' <value=.number>)
            | @<entries=truce_months>                 = (<key=.kw('truce_months')>                 '=' <value=.number>)

            | @<entries=good_relation_prestige_factor>  = (<key=.kw('good_relation_prestige_factor')>  '=' <value=.number>)
            | @<entries=good_relation_infamy_factor>    = (<key=.kw('good_relation_infamy_factor')>    '=' <value=.number>)
            | @<entries=good_relation_militancy_factor> = (<key=.kw('good_relation_militancy_factor')> '=' <value=.number>)

            | @<entries=can_use>                  = (<key=.kw('can_use')>                  '=' <value=.trigger-block>)
            | @<entries=is_valid>                 = (<key=.kw('is_valid')>                 '=' <value=.trigger-block>)
            | @<entries=allowed_countries>        = (<key=.kw('allowed_countries')>        '=' <value=.trigger-block>)
            | @<entries=allowed_states>           = (<key=.kw('allowed_states')>           '=' <value=.trigger-block>)
            | @<entries=allowed_substate_regions> = (<key=.kw('allowed_substate_regions')> '=' <value=.trigger-block>)
            | @<entries=allowed_states_in_crisis> = (<key=.kw('allowed_states_in_crisis')> '=' <value=.trigger-block>)

            | @<entries=all_allowed_states>       = (<key=.kw('all_allowed_states')>       '=' <value=.yes-or-no>)

            | @<entries=options=po_status_quo>                   = (<key=.kw('po_status_quo')>                   '=' <value=.yes-or-no>)
            | @<entries=options=po_annex>                        = (<key=.kw('po_annex')>                        '=' <value=.yes-or-no>)
            | @<entries=options=po_demand_state>                 = (<key=.kw('po_demand_state')>                 '=' <value=.yes-or-no>)
            | @<entries=options=po_transfer_provinces>           = (<key=.kw('po_transfer_provinces')>           '=' <value=.yes-or-no>)
            | @<entries=options=po_disarmament>                  = (<key=.kw('po_disarmament')>                  '=' <value=.yes-or-no>)
            | @<entries=options=po_reparations>                  = (<key=.kw('po_reparations')>                  '=' <value=.yes-or-no>)
            | @<entries=options=po_remove_prestige>              = (<key=.kw('po_remove_prestige')>              '=' <value=.yes-or-no>)
            | @<entries=options=po_remove_cores>                 = (<key=.kw('po_remove_cores')>                 '=' <value=.yes-or-no>)
            | @<entries=options=po_gunboat>                      = (<key=.kw('po_gunboat')>                      '=' <value=.yes-or-no>)
            | @<entries=options=po_colony>                       = (<key=.kw('po_colony')>                       '=' <value=.yes-or-no>)
            | @<entries=options=po_add_to_sphere>                = (<key=.kw('po_add_to_sphere')>                '=' <value=.yes-or-no>)
            | @<entries=options=po_clear_union_sphere>           = (<key=.kw('po_clear_union_sphere')>           '=' <value=.yes-or-no>)
            | @<entries=options=po_make_puppet>                  = (<key=.kw('po_make_puppet')>                  '=' <value=.yes-or-no>)
            | @<entries=options=po_release_puppet>               = (<key=.kw('po_release_puppet')>               '=' <value=.yes-or-no>)
            | @<entries=options=po_install_communist_gov_type>   = (<key=.kw('po_install_communist_gov_type')>   '=' <value=.yes-or-no>)
            | @<entries=options=po_uninstall_communist_gov_type> = (<key=.kw('po_uninstall_communist_gov_type')> '=' <value=.yes-or-no>)
            | @<entries=options=po_destroy_forts>                = (<key=.kw('po_destroy_forts')>                '=' <value=.yes-or-no>)
            | @<entries=options=po_destroy_naval_bases>          = (<key=.kw('po_destroy_naval_bases')>          '=' <value=.yes-or-no>)

            | @<entries=tws_battle_factor> = (<key=.kw('tws_battle_factor')> '=' <value=.number>)

            | @<entries=war_name>          = (<key=.kw('war_name')>          '=' <value=.text>)

            | @<entries=on_add>            = (<key=.kw('on_add')>            '=' <value=.effect-block>)
            | @<entries=on_po_accepted>    = (<key=.kw('on_po_accepted')>    '=' <value=.effect-block>)
        ]*
    }

    method validate-casus-belli {
        my (\cb, \cb-block) = self<key value>;

        given cb-block {
            .prefer-one(cb, "sprite_index", kinds => 0 => Remark::Missing-Info);

            for <
                months
                badboy_factor prestige_factor peace_cost_factor penalty_factor
                break_truce_prestige_factor break_truce_infamy_factor break_truce_militancy_factor truce_months
            > -> \entry {
                .prefer-one(cb, entry)
            }

            # N.b. hardcoding is justified because these CBs are hardcoded in the game’s machinery
            if cb.&kw ∈ ("status_quo".fc, "gunboat".fc).Set {
                for <
                    good_relation_prestige_factor good_relation_infamy_factor good_relation_militancy_factor
                > -> \entry {
                    .prefer-at-most-one(cb, entry)
                }
            } else {
                for <
                    good_relation_prestige_factor good_relation_infamy_factor good_relation_militancy_factor
                > -> \entry {
                    .prefer-one(cb, entry)
                }
            }

            for <
                is_triggered_only crisis construction_speed constructing_cb great_war_obligatory
                always is_civil_war
            > -> \entry {
                .prefer-at-most-one(cb, entry)
            }

            # NYI: trigger validation
            # NYI: peace option validation

            .prefer-one(cb, "war_name", kinds => 0 => Remark::Missing-Localisation);
            .prefer-one(cb, "on_add", missing => Remark::Convention => qq:to«END».chomp);
            Adding a CB should cost jingoism support in the country.
            If you intend to make an exception to this rule, consider still leaving an $*STYLES.code("on_add") block
            with a comment inside to document that fact. This will make it clear it’s a deliberate design and not an
            oversight.
            END
            .prefer-at-most-one(cb, "on_po_accepted");
        }

        $.ok
    }

    method validate-casus-belli-file {
        $.ok
    }
}

#| Parse an event file.
our grammar Events is Base {
    method topo-level { 1 }
    method where      { <events> }
    method what       { Any }
    method descr      { "event files" }

    rule TOP(Styles:D :$styles!, Str :$source, :%universe = %()) {
        :my $*STYLES   = $styles;
        :my $*SOURCE   = $source;
        :my %*UNIVERSE = %universe;
        :my @*REMARKS;

        ^ [
            | @<entries=country-events>=<.country-event>
            | @<entries=province-events>=<.province-event>
        ]* $

        {
            my \incomplete-universe = do unless %universe<casus-belli>:exists {
                qq:to«END».chomp,
                While analysing $.descr():
                some effects will not be fully validated unless $*STYLES.quote-path("common/cb_types.txt") is analysed.
                END
            }

            remake(
                $/,
                REMARKS => @*REMARKS,
                RESULT  => event-ids => %(
                    $source => @<entries>.map(&event-id).grep(*.defined).List
                ),
                INCOMPLETE-UNIVERSE => incomplete-universe,
            )
        }
    }

    rule country-event  {
        <key=.kw('country_event')>  '=' <value=.country-event-block>
        {} <.validate-event>
    }
    rule province-event {
        <key=.kw('province_event')> '=' <value=.province-event-block>
        {} <.validate-event>
    }

    rule country-event-block {
        '{' ~ '}' [
            | <entries=id>

            | <entries=title>
            | <entries=desc>
            | <entries=picture>
            | <entries=major>
            | <entries=election>
            | <entries=issue_group>

            | <entries=news>
            | <entries=news_title>
            | <entries=news_desc_long>
            | <entries=news_desc_medium>
            | <entries=news_desc_short>

            | <entries=is_triggered_only>
            | <entries=fire_only_once>
            | <entries=allow_multiple_instances>

            | <entries=event_trigger>
            | <entries=mean_time_to_happen>

            | <entries=immediate>
            | <entries=options=.option>
        ]*
    }

    method province-event-block() { self.country-event-block }

    rule id                       { <key=.kw('id')>                       '=' <value=.number>   }
    rule title                    { <key=.kw('title')>                    '=' <value=.text>     }
    rule desc                     { <key=.kw('desc')>                     '=' <value=.text>     }
    rule picture                  { <key=.kw('picture')>                  '=' <value=.text>     }
    rule major                    { <key=.kw('major')>                    '=' <value=.yes-or-no> }
    rule election                 { <key=.kw('election')>                 '=' <value=.yes-or-no> }
    rule issue_group              { <key=.kw('issue_group')>              '=' <value=.text> }

    rule news                     { <key=.kw('news')>                     '=' <value=.yes-or-no> }
    rule news_title               { <key=.kw('news_title')>               '=' <value=.text> }
    rule news_desc_long           { <key=.kw('news_desc_long')>           '=' <value=.text> }
    rule news_desc_medium         { <key=.kw('news_desc_medium')>         '=' <value=.text> }
    rule news_desc_short          { <key=.kw('news_desc_short')>          '=' <value=.text> }

    rule is_triggered_only        { <key=.kw('is_triggered_only')>        '=' <value=.yes-or-no> }
    rule fire_only_once           { <key=.kw('fire_only_once')>           '=' <value=.yes-or-no> }
    rule allow_multiple_instances { <key=.kw('allow_multiple_instances')> '=' <value=.yes-or-no> }

    rule event_trigger            { <key=.kw('trigger')>                  '=' <value=.trigger-block> }
    rule mean_time_to_happen      { <key=.kw('mean_time_to_happen')>      '=' <value=.block> }

    rule immediate                { <key=.kw('immediate')>                '=' <value=.effect-block> }
    rule option                   { <key=.kw('option')>                   '=' <value=.option-block> }

    rule option-block {
        '{' ~ '}' [
            | @<entries=name>=(<key=.kw('name')> '=' <value=.simplex>)
            | @<entries=ai_chance>=(<key=.kw('ai_chance')> '=' <value=.trigger-block>)

            # catch-all
            | {} <entries=effects=.effect($/)>
        ]*
    }

    method validate-event {
        my (\event, \event-block) = self<key value>;

        given event-block {
            my Str:D $id = $*STYLES.important(
                do .expect-one(event, "id")<value> andthen .Str orelse "<no id provided>"
            );
            my Str:D $element = $*STYLES.code("{self<key>.Str} $id");

            .prefer-one(event, "title", kinds => 0 => Remark::Missing-Localisation, :$element);
            .prefer-one(event, "desc", kinds => 0 => Remark::Missing-Localisation, :$element);

            for <picture major election issue_group
                 news news_title news_desc_long news_desc_medium news_desc_short
                 is_triggered_only fire_only_once allow_multiple_instances
                 event_trigger mean_time_to_happen
                 immediate> -> $entry {
                event-block.prefer-at-most-one(event, $entry, :$element);
            }

            given .<major>[0], .<picture>[0] {
                when { .&yes }, ?* {
                    .[0].opinion(extra-locs => .[1,]»<key>, qq:to«END».chomp);
                    $element is major and has a picture (no picture is required for major events)
                    END
                }

                when { .&no }, !* {
                    # AI-only events are allowed not to have a picture
                    unless
                        (event-block<event_trigger>[0]<value><ai>[0].&yes)
                        # province events don’t have pictures
                        || event.&kw eq "province_event".fc {
                        event.missing-info(qq:to«END».chomp);
                        $element is missing a picture
                        END
                    }
                }
            }

            my \news_descs = <news_desc_long news_desc_medium news_desc_short>;
            if .<news>[0].&yes {
                my @missing-descs = .{news_descs}:p.grep(!*.value).map(*.key);

                .<news>[0].missing-info(qq:to«END».chomp) if @missing-descs;
                $element is set to appear in the news, but is missing some news descriptions:
                    {@missing-descs.map({ $*STYLES.code($_) }).join(", ")}
                END
            } else {
                my @extra-locs = .{news_descs}.flat.grep(?*).map(*<key>).sort(*.pos);

                (.<news>[0] // event).opinion(qq:to«END».chomp, :@extra-locs) if @extra-locs;
                $element is set not to appear in the news, but has news descriptions
                END
            }

            given .<is_triggered_only>[0], .<event_trigger>[0], .<mean_time_to_happen>[0] {
                when ({ .&yes }, Any, Any) & { ?.[1] | ?.[2] } {
                    # TODO on-action events
                    my @extra-locs = .[1..*].grep(?*).map(*<key>).sort(*.pos);
                    .[0].opinion(qq:to«END».chomp, :@extra-locs)
                    $element is triggered only, but has redundant entries:
                        { @extra-locs.map({ $*STYLES.code(.Str) }).join(", ") }
                    (Ignoring on-action events not yet implemented.)
                    END
                }

                when ({ .&no }, !*, Any) {
                    (.[0] // event).opinion(qq:to«END».chomp);
                    $element has no $*STYLES.code("trigger"). Either:
                    • add a $*STYLES.code("trigger"), if the event is intended to activate by itself
                    • set the following, if the event is only ever activated by e.g. other events or decisions:
                        $*STYLES.code-quote("is_triggered_only = $*STYLES.code-focus("yes")")
                    END

                    proceed
                }

                when ({ .&no }, !*, ?*) {
                    .[2]<key>.opinion(qq:to«END».chomp)
                    $element has a $*STYLES.code("mean_time_to_happen") but no $*STYLES.code("trigger")
                    END
                }
            }

            for .expect-some(event, "options", entry => $*STYLES.code("option"), :$element) {
                my (\option, \option-block) = .<key value>;

                my %kinds = %(
                    0   => Remark::Missing-Localisation,
                    Inf => Remark::Opinion,
                );
                option-block.prefer-one(option, "name", :%kinds, element => "an option of $element");

                option-block.prefer-at-most-one(option, "ai_chance", element => "an option of $element");
            }
        }

        $.ok
    }
}

our sub event-id(\ast where Any:U|Match --> Int) is export(:ast)
{
    pair(ast)
    && ast<key>.&kw ~~ ('country_event', 'province_event').any.fc
    && ast<value><id>[0]<value>
    andthen .Int orelse Int
}
