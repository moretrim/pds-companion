=begin COPYRIGHT
Copyright © 2019–2020 moretrim.

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

#| Base for common items for Victoria 2 grammars.
our grammar Base is PDS::Unstructured {
    ## Triggers

    rule trigger {
        | $<soup=ai>=(<key=.kw('ai')> '=' <value=.yes-or-no>)

        # catch-all
        | $<soup>=(<key=.simplex> '=' [<value=.simplex>|<value=.trigger-block>])
    }

    rule trigger-block {
        '{' ~ '}' <entries=.trigger>*
    }

    ## Effects

    rule effect {
        | <soup=add_country_modifier>
        | <soup=add_province_modifier>
        | <soup=country-event-effect>
        | <soup=province-event-effect>

        # catch-all
        | $<soup>=(<key=.simplex> '=' [<value=.simplex>|<value=.effect-block>])
    }

    rule effect-block {
        '{' ~ '}' <entries=.effect>*
    }

    rule add_country_modifier  {
        <key=.kw("add_country_modifier")> '=' <value=.name-duration-block>
        {} <validate-modifier>
    }
    rule add_province_modifier {
        <key=.kw("add_province_modifier")> '=' <value=.name-duration-block>
        {} <validate-modifier>
    }

    rule name-duration-block {
        '{' ~ '}' [
            [
                @<entries=name>=(<key=.kw('name')>         '=' <value=.text>)
                @<entries=duration>=(<key=.kw('duration')> '=' <value=.number>)
            ] | [
                @<entries=duration>=(<key=.kw('duration')> '=' <value=.number>)
                @<entries=name>=(<key=.kw('name')>         '=' <value=.text>)
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
                @<entries=id>=(<key=.kw('id')> '=' <value=.number>)
                @<entries=days>=(<key=.kw('days')> '=' <value=.number>)
            ] | [
                @<entries=days>=(<key=.kw('days')> '=' <value=.number>)
                @<entries=id>=(<key=.kw('id')> '=' <value=.number>)
            ]
        ]
    }
}

our sub event-effect-id(\ast where Any:U|Match --> Int) is export(:ast)
{
    pair(ast)
    && ast<key>.&kw ~~ ('country_event', 'province_event').any.fc
    && ast<value>.&{ .<soup>, .<id>[0]<value> }.grep(*.defined)[0]
    andthen .Int orelse Int
}

#| Parse an event file.
our grammar Events is Base {
    method where { <events> };
    method descr { "event files" };

    rule TOP(Styles:D :$styles!, Str :$source) {
        :my $*STYLES = $styles;
        :my $*SOURCE = $source;
        :my @*REMARKS;
        ^ [
            | @<entries=country-events>=<.country-event>
            | @<entries=province-events>=<.province-event>
        ]* $
        { remake($/, REMARKS => @*REMARKS) }
    }

    rule country-event  {
        <key=.kw('country_event')>  '=' <value=.country-event-block>
        {} <validate-event>
    }
    rule province-event {
        <key=.kw('province_event')> '=' <value=.province-event-block>
        {} <validate-event>
    }

    rule country-event-block {
        :my $id = Int;
        '{' ~ '}' [
            | @<entries>=<id> { with @<id>[0]<value>.Int { $id = $_ } }

            | @<entries>=<title>
            | @<entries>=<desc>
            | @<entries>=<picture>
            | @<entries>=<major>
            | @<entries>=<election>
            | @<entries>=<issue_group>

            | @<entries>=<news>
            | @<entries>=<news_title>
            | @<entries>=<news_desc_long>
            | @<entries>=<news_desc_medium>
            | @<entries>=<news_desc_short>

            | @<entries>=<is_triggered_only>
            | @<entries>=<fire_only_once>
            | @<entries>=<allow_multiple_instances>

            | @<entries>=<event_trigger>
            | @<entries>=<mean_time_to_happen>

            | @<entries>=<immediate>
            | @<entries=options>=<.option>
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
            | <entries=.effect>
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
                when &yes, ?* {
                    .[0].opinion(extra-locs => .[1,]»<key>, qq:to«END».chomp);
                    $element is major and has a picture (no picture is required for major events)
                    END
                }

                when &no, !* {
                    # AI-only events are allowed not to have a picture
                    unless (event-block<event_trigger>[0]<value><ai>[0].&yes) {
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
                when (&yes, Any, Any) & { ?.[1] | ?.[2] } {
                    # TODO on-action events
                    my @extra-locs = .[1..*].grep(?*).map(*<key>).sort(*.pos);
                    .[0].opinion(qq:to«END».chomp, :@extra-locs)
                    $element is triggered only, but has redundant entries:
                        { @extra-locs.map({ $*STYLES.code(.Str) }).join(", ") }
                    (Ignoring on-action events not yet implemented.)
                    END
                }

                when (&no, !*, Any) {
                    (.[0] // event).opinion(qq:to«END».chomp);
                    $element has no $*STYLES.code("trigger"). Either:
                    • add a $*STYLES.code("trigger"), if the event is intended to activate by itself
                    • set the following, if the event is only ever activated by e.g. other events or decisions:
                        $*STYLES.code-quote("is_triggered_only = $*STYLES.code-focus("yes")")
                    END

                    proceed
                }

                when (&no, !*, ?*) {
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
