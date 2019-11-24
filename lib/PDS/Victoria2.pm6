=begin COPYRIGHT
Copyright © 2019 moretrim.

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

use PDS :ast;
use remake;

constant Remark = PDS::Remark;

#| Base for common items for Victoria 2 grammars.
our grammar Base is PDS::Unstructured {
    rule trigger-block {
        '{' ~ '}' [
            | @<entries>=(<key=.kw('ai')> '=' <value=.yes-or-no>)
            # catch-all
            | @<entries>=(<key=.simplex> '=' [<value=.simplex>|<value=.trigger-block>])
        ]*
    }

    rule effect-block {
        '{' ~ '}' [
            | @<entries>=(<key=.kw('add_country_modifier')> '=' <value=.name-duration-block>)
            | @<entries>=(<key=.kw('add_province_modifier')> '=' <value=.name-duration-block>)
            # catch-all
            | @<entries>=(<key=.simplex> '=' [<value=.simplex>|<value=.effect-block>])
        ]*
    }

    rule name-duration-block {
        '{' ~ '}' [
            | @<entries>=(<key=.kw('name')> '=' <value=.text>)
            | @<entries>=(<key=.kw('duration')> '=' <value=.number>)
        ]*
    }
}

#| Parse an event file.
our grammar Events is Base {
    method where { <events> };
    method descr { "event files" };

    rule TOP {
        :my @*REMARKS;
        ^ [
            | @<entries=country-events>=<.country-event>
            | @<entries=province-events>=<.province-event>
        ]* $
        { remake($/, REMARKS => @*REMARKS) }
    }

    rule country-event  { <key=.kw('country_event')>  '=' <value=.country-event-block> }
    rule province-event { <key=.kw('province_event')> '=' <value=.province-event-block> }

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
            | @<entries=options>=<.option($id)>
        ]*
        {} <validate-event-block($/)>
    }

    method province-event-block() { self.country-event-block }

    method validate-event-block(Match:D $_) {
        my Match $match = $_;

        given .<id>.elems {
            when 1  { #`(fine) }
            when 0  { self.error("event is missing an ID") }
            default { self.error("event has too many IDs") }
        }
        my Int $id = .<id>[0]<value>.Int;

        given .<title> {
            when .elems == 1 { #`(fine) }
            when .elems == 0 { $match.remark(Remark::Opinion, "event $id is missing a title") }
            default          { .[0].remark(Remark::Opinion, "event $id has too many titles") }
        }

        given .<desc> {
            when .elems == 1 { #`(fine) }
            when .elems == 0 { $match.remark(Remark::Opinion, "event $id is missing a description") }
            default          { .[0].remark(Remark::Opinion, "event $id has too many descriptions") }
        }

        for <picture major election issue_group
             news news_title news_desc_long news_desc_medium news_desc_short
             is_triggered_only fire_only_once allow_multiple_instances
             event_trigger mean_time_to_happen
             immediate> -> $entry {
            if .{$entry}.elems > 1 {
                .{$entry}[0].remark(Remark::Opinion, "event $id has too many ‘$entry’ entries")
            }
        }

        given (.<picture>, .<major>)».elems.sum {
            when 0  {
                # AI-only events are allowed to not have a picture
                unless ($match<event_trigger>[0]<value><ai>[0].&yes) {
                    $match.remark(Remark::Opinion, "event $id is missing a picture")
                }
            }
            when 2  { $match<major>[0].remark(Remark::Opinion, qq:to«END».chomp) if $match<major>[0].&yes; }
            event $id is major and has a picture (no picture is required for major events)
            END
        }

        my \news_descs = <news_desc_long news_desc_medium news_desc_short>;
        if .<news>[0].&yes {
            my @missing-descs;
            news_descs
                ==> grep({ $match{$_}[0]:!exists })
                ==> @missing-descs;
            .<news>[0].remark(Remark::Opinion, qq:to«END».chomp) if @missing-descs;
            event $id is missing some news descriptions ({@missing-descs.join(', ')})
            END
        } elsif news_descs.map({ $match{$_}.elems }).sum != 0 {
            my @extra-descs;
            news_descs
                ==> grep({ $match{$_}[0]:exists })
                ==> @extra-descs;
            @extra-descs[0].remark(Remark::Opinion, qq:to«END».chomp) if @extra-descs;
            event $id set to no news, but has news descriptions ({@extra-descs.join(', ')})
            END
        }

        if .<is_triggered_only>[0].&yes {
            given $match<event_trigger>, $match<mean_time_to_happen> {
                when (), *.elems { $match<mean_time_to_happen>[0].remark(Remark::Opinion, qq:to«END».chomp) }
                event $id has a mean time to happen but no trigger
                END
            }
        }

        if .<options>.elems == 0 {
            self.error("event $id is missing an option")
        }

        self.ok
    }

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
    rule option(Int $id)          { <key=.kw('option')>                   '=' <value=.option-block($id)> }

    rule option-block(Int $id) {
        <soup=.effect-block>
        {} <validate-option-block($id, $/)>
    }

    rule option-name { <key=.kw('name')> '=' <value=.simplex> }

    method validate-option-block(Int $id, Match:D $_) {
        my Match $match = $_;

        given .<name>.elems {
            when 1  { #`(fine) }
            when 0  { self.error(qq:to«END».chomp); }
            option in event $(with $id { "$_ " } else { '' })is missing a name
            END
            default { self.error(qq:to«END».chomp); }
            option in event $(with $id { "$_ " } else { '' })has too many names
            END
        }

        self.ok
    }
}
