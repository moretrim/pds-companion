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


# no precompilation;
# use Grammar::Tracer;

use PDS;

#| Base for common items for Victoria 2 grammars.
our grammar Base is PDS::Grammar {
    rule condition { <soup=.block> }
}

#| Parse an event file.
our grammar Events is Base {
    rule TOP {
        ^ [
            | @<entries=country-events>=<.country-event>
            | @<entries=province-events>=<.province-event>
        ]* $
    }

    rule country-event  { $<key>=('country_event')  '=' <value=.country-event-block> }
    rule province-event { $<key>=('province_event') '=' <value=.province-event-block> }

    rule country-event-block {
        :my $id = Int;
        '{' ~ '}' [
            | @<entries>=<id> { with @<id>[0]<value>.made { $id = $_ } }

            | @<entries>=<title>
            | @<entries>=<desc>
            | @<entries>=<picture>
            | @<entries>=<major>

            | @<entries>=<news>
            | @<entries>=<news-desc-long>
            | @<entries>=<news-desc-medium>
            | @<entries>=<news-desc-short>

            | @<entries>=<is-triggered-only>
            | @<entries>=<fire-only-once>
            | @<entries>=<allow-multiple-instances>

            | @<entries>=<trigger>
            | @<entries>=<mean-time-to-happen>

            | @<entries=options>=<.option($id)>
        ]*
        {} <validate-event-block($/)>
    }

    method validate-event-block(Match:D $_) {
        my Match $match = $_;

        given .<id>.elems {
            when 1  { #`(fine) }
            when 0  { self.error("event is missing an ID") }
            default { self.error("event has too many IDs") }
        }
        my Int $id = .<id>[0]<value>.made;

        given .<title>.elems {
            when 1  { #`(fine) }
            when 0  { self.error("event $id is missing a title") }
            default { self.error("event $id has too many titles") }
        }

        given .<desc>.elems {
            when 1  { #`(fine) }
            when 0  { self.error("event $id is missing a description") }
            default { self.error("event $id has too many descriptions") }
        }

        for <picture major
             news news-desc-long news-desc-medium news-desc-short
             is-triggered-only fire-only-once allow-multiple-instances
             trigger mean-time-to-happen> -> $entry {
            if .{$entry}.elems > 1 {
                self.error("event $id has too many ‘$($entry.subst('-', '_', :g))’ entries")
            }
        }

        given (.<picture>, .<major>)».elems.sum {
            when 0  { self.error("event $id is missing a picture") }
            when 2  { self.error(qq:to«END».chomp) if $match.<major>[0]<value>.made; }
            event $id is major and has a picture (no picture is required for major events)
            END
        }

        my \news-descs = <news-desc-long news-desc-medium news-desc-short>;
        if .<news>[0]<value> andthen .made {
            my @missing-descs;
            news-descs
                ==> grep({ $match{$_}[0]:!exists })
                ==> @missing-descs;
            self.error(qq:to«END».chomp) if @missing-descs;
            event $id is missing some news descriptions ({@missing-descs».subst('-', '_', :g).join(', ')})
            END
        } elsif news-descs.map({ $match{$_}.elems }).sum != 0 {
            # my @extra-descs;
            # news-descs
            #     ==> grep({ $match{$_}[0]:exists })
            #     ==> @extra-descs;
            # self.error(qq:to«END».chomp) if @extra-descs;
            # event $id set to no news, but has news descriptions ({@extra-descs».subst('-', '_', :g).join(', ')})
            # END
        }

        if .<is-triggered-only>[0]<value> andthen .made {
            given $match<trigger>, $match<mean-time-to-happen> {
                when (), *.elems { self.error(qq:to«END».chomp) }
                event $id has a mean time to happen but no trigger
                END
            }
        }

        if .<options>.elems == 0 {
            self.error("event $id is missing an option")
        }

        self.ok
    }

    rule id                       { $<key>=('id')                       '=' <value=.number>   }
    rule title                    { $<key>=('title')                    '=' <value=.text>     }
    rule desc                     { $<key>=('desc')                     '=' <value=.text>     }
    rule picture                  { $<key>=('picture')                  '=' <value=.text>     }
    rule major                    { $<key>=('major')                    '=' <value=.yes-or-no> }

    rule news                     { $<key>=('news')                     '=' <value=.yes-or-no> }
    rule news-desc-long           { $<key>=('news_desc_long')           '=' <value=.text> }
    rule news-desc-medium         { $<key>=('news_desc_medium')         '=' <value=.text> }
    rule news-desc-short          { $<key>=('news_desc_short')          '=' <value=.text> }

    rule is-triggered-only        { $<key>=('is_triggered_only')        '=' <value=.yes-or-no> }
    rule fire-only-once           { $<key>=('fire_only_once')           '=' <value=.yes-or-no> }
    rule allow-multiple-instances { $<key>=('allow_multiple_instances') '=' <value=.yes-or-no> }

    rule trigger                  { $<key>=('trigger')                  '=' <value=.condition> }
    rule mean-time-to-happen      { $<key>=('mean_time_to_happen')      '=' <value=.block> }

    rule option(Int $id)          { $<key>=('option')                   '=' <value=.option-block($id)> }

    rule option-block(Int $id) {
        '{' ~ '}' [
            | @<entries=name>=<.option-name>
            | @<entries=effects>=<.pair>
        ]*
        {} <validate-option-block($id, $/)>
    }

    rule option-name { $<key>=('name') '=' <value=.simplex> }

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
