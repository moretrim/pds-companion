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

#| Tools to help with modding Paradox Development Studio games.
unit module PDS;

use PDS::remake;
use PDS::Styles;

=head2 Source Report

#| A source context is a line number, acting as the line focus, together with part of the source script.
subset Context of Pair where (.key, .value) ~~ (Int:D, Str:D);

# L<Contextualising> is a supporting role for the purpose of making reports. Due to order of definition concerns, it
# appears after L<Scaffolding>.

#| A source report is a human-friendly message, together with a number of line-annotated, formatted excerpts from the
#| original source.
class Report does Styles::Stylish {
    ## Definitional report information, participates in WHICH

    has #`(Context) @.contexts is List:D; #=[ L<Context> pairs of (line => formatted source) context information
                                              relevant to the report
                                          ]
    has Str:D       $.message = "";       #= human-friendly message

    ## Extraneous report information, does not participate in WHICH (neither does $.styles)

    has %.annotations is rw; #= extra report information

    method WHICH(--> ValueObjAt:D) {
        ValueObjAt.new(($.^name, |(self andthen @.contexts.WHICH, $.message.WHICH)).join("|"))
    }

    #| Turn a single report into human-friendly text. The format has three possible outcomes.
    method format-report(
        Int:D :$first-column-width = 0, #= for alignment purposes
        --> Str:D
    ) {
        # refer to `Contextualising::&context` to see why line 0 really means the start of the script
        sub line-location(Int:D $_) {
            when 0  { "at $.styles.attention("the start of the script")" }
            default { "around line $.styles.attention(.fmt("%{$first-column-width}d"))" }
        }

        sub format-context(Str:D $_) {
            when "" { Empty }
            default { .indent(4) }
        }

        my \formatted-contexts = do given @.contexts {
            when .elems == 1 {
                (
                    line-location(.[0].key).tc,
                    format-context(.[0].value),
                ).join(": \n")
            }

            default {
                qq:to«END».chomp;
                In the following:
                {
                    .map({
                        (
                            "‣ &line-location(.key)",
                            format-context(.value)
                        ).join("\n"),
                    }).join("\n")
                }
                END
            }
        }

        my \annotation-header = %.annotations ?? "\nThe following extra information is included:" !! "";
        my \annotation-report = "{annotation-header}{ %.annotations.map({ "\n    {.key} => {.value.gist}" }) }";

        (
            formatted-contexts,
            "{$.message}{$.styles.unimportant(annotation-report.indent(4))}"
        ).join("\n")
    }

    #| Turn multiple reports into human-friendly text at once. Performs some alignment.
    our sub format-reports(
        #`(::?CLASS) @reports,
        --> List:D
    ) {
        my \line-width = [max] @reports.map({ .contexts.map({ .key.chars.Slip }).Slip });
        @reports.map({
            .format-report(first-column-width => line-width)
        }).List
    }
}

multi infix:«eqv»(Report:D \left, Report:D \right --> Bool:D) is export
{ (left.contexts, left.message) eqv (right.contexts, right.message) }

=head2 Errors & Remarks

#| Base exception for all fatal parsing errors.
#|
#| Thrown when a L<PDS::Grammar> reports a fatal error and parsing cannot proceed any further.
class GLOBAL::X::PDS::ParseError is Exception {
    has $.source is rw;
    has Report $.report handles «styles contexts format-report :message("format-report")»;
}

#| Enable L<Match> to report fatal errors. Assumes L<Contextualising>.
role ErrorReporting {
    #| When parsing cannot proceed any further, throw a L<X::PDS::ParseError>.
    method fatal-error(
        $reason,                        #= reason for failure to parse
        #`(::?CLASS) :@extra-locs = (), #= extra source locations relevant to the report
        :$styles = $*STYLES,            #= style override, useful when not called from a parse e.g. during testing
        :$source = $*SOURCE,            #= source override
        *%annotations,                  #= additional information
    ) {
        my @contexts = (self.context(:$styles, :focus-anchor), |@extra-locs.map({ .context(:$styles) }));
        X::PDS::ParseError.new(
            report => Report.new(
                :$styles,
                :@contexts,
                message => $reason,
                :%annotations,
            )
        ).throw
    }

    method FAILGOAL($goal) {
        self.fatal-error("expected closing $goal.trim()");
    }
}

#| When something is not quite a fatal error that needs to be reported through L<fatal-error>, a grammar can instead
#| report it as a remark. Assumes L<Contextualising>.
#|
#| Fatal errors (reported by L<fatal-error> by throwing a L<X::PDS::ParseError>) and remarks with kind L<Error> together
#| constitute all errors that can be found within a script. Remarks of a different kinds serve a more advisory role.
class Remark {
    #| A L<Remark> has exactly one kind. The kind value is useful for sorting, with least value (starting from zero)
    #| meaning most urgent priority.
    enum Kind « Error Quirk Convention Missing-Localisation Missing-Info Opinion »;

    #| Each L<Kind> symbol is associated with the following attributes:
    #| - C<.<descr>>, which describes its purpose
    #|
    #| This is provided as an external method and not as the enumerator value to prevent enumerator confusion (e.g.
    #| performing set operations such as intersection or inclusion on the symbols, and not their values).
    our method kind-attrs(Kind:D $_: Styles:D :$styles! --> Map:D) {
        when Error {
            %(
                descr => qq:to«END».chomp,
                $styles.important("Errors") in the script that the game cannot handle.
                These should be resolved to prevent the game from crashing or behaving erratically
                END
            ).Map
        }

        when Quirk {
            %(
                descr => qq:to«END».chomp,
                $styles.important("Quirks") from the game that are usually undesirable
                END
            ).Map
        }

        when Convention {
            %(
                descr => qq:to«END».chomp,
                $styles.important("Conventions") common among modders.
                Suggested so that the code can be better understood by others
                END
            ).Map
        }

        when Missing-Localisation {
            %(
                descr => qqw:to«END».join(" "),
                $styles.important("Missing localisation") that results in the game showing internal strings, which is
                not fatal but can confuse players
                END
            ).Map
        }

        when Missing-Info {
            %(
                descr => qqw:to«END».join(" "),
                $styles.important("Missing information") (other than localisation text) that is not fatal
                END
            ).Map
        }

        when Opinion {
            %(
                descr => qqw:to«END».join(" "),
                $styles.important("Matters of opinion"), for writing consistent PDS script
                END
            ).Map
        }
    }

    has Kind:D $.kind = Error;
    has Report $.report handles «styles contexts format-report»;

    method WHICH(--> ValueObjAt:D) {
        ValueObjAt.new(($.^name, |(self andthen $.kind.WHICH, $.report.WHICH)).join("|"));
    }
}

multi infix:«eqv»(Remark:D \left, Remark:D \right --> Bool:D) is export
{
    [&&] (left.kind, left.report) Zeqv (right.kind, right.report)
}

#| Convenience for e.g. using L<cmp-ok> instead of L<is-deeply>, since lexical scoping means that L<List>’s
#| C<infix:«eqv»> cannot hope to find our own L<infix:«eqv»> multis.
our sub eqv-remarks(@left, @right)
{ @left.elems == @right.elems && [&&] @left Zeqv @right }

#| Store remarks.
role Remarking {
    method remark(
        Remark::Kind:D $kind,                #= kind of remark
        Str:D $message,                      #= message to attach to the context
        #`(::?CLASS) :@extra-locs = (),      #= extra source locations relevant to the remark
        Bool :$preserve-trailing-whitespace, #=[ preserve trailing whitespace from the context anchors (useful e.g. when
                                                 the report is about that whitespace)
                                             ]
    ) {
        my $styles = $*STYLES;
        my @contexts = (
            self.context(:$styles, :focus-anchor, :$preserve-trailing-whitespace),
            |@extra-locs.map({ .context(:$styles, :$preserve-trailing-whitespace) })
        );
        @*REMARKS.push(Remark.new(:$kind, report => Report.new(:$styles, :@contexts, :$message)));
        Nil
    }

    # Conveniences

    method error(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Error, $message, :@extra-locs)
    }

    method quirk(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Quirk, $message, :@extra-locs)
    }

    method convention(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Convention, $message, :@extra-locs)
    }

    method missing-localisation(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Missing-Localisation, $message, :@extra-locs)
    }

    method missing-info(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Missing-Info, $message, :@extra-locs)
    }

    method opinion(Str:D $message, #`(::?CLASS) :@extra-locs = ()) {
        $.remark(Remark::Kind::Opinion, $message, :@extra-locs)
    }
}

=head2 Grammar Generalities

#| Lexing scaffolding for PDS script.
role Scaffolding {
    # N.b. handling of non NL-terminated input
    regex wb { <?after <.syntax-char>|^|$> }
    regex comment {
        :r [ $<comment-header>=<[#;]> \V* ]+ % [ \n\s* ] [ \n | $ ]
        { $/.catch-non-standard-comment-header }
    }
    method catch-non-standard-comment-header() {
        for self<comment-header>.grep({ $_ eq ';' }) {
            .opinion(qq:to«END».chomp, :preserve-trailing-whitespace)
            Use of non-standard comment header {$*STYLES.code-quote(";")}, prefer {$*STYLES.code-quote("#")}.
            END
        }
    }
    regex ws { :r <|wb> [ <comment> | \s+ ]* }

    # N.b. PDS script files use octet-oriented encodings via Windows code pages. We go along with what the most of
    # modding community is doing by sticking to Windows-1252 (aka CP-1252).
    #
    # Some parsing notes:
    #
    # Some characters have a syntactical meaning and cannot appear in identifiers unless quoted, except that the double
    # quote ‘"’ itself cannot be escaped:
    # - comment marker: #
    # - optional quote marker for identifiers (esp. localisation keys): "
    # - equals sign for key/value pairs: =
    # - brackets for blocks: {}
    #
    # Semicolon ‘;’ appears to be functioning as a line comment marker, though there is no instance of it in the
    # Victoria 2 files save for one ambiguous case where it innocuously terminates the line. Because mods may include
    # this file we do accept the character as a comment marker even though this may just be the parser choking on it and
    # the rest of the line with it. This may also lead the user to misleadingly assume that semicolons work as a
    # separator.
    #
    # Comma ‘,’ appears to work the same as semicolon though we don't accept it since it doesn't appear in the PDS
    # files.
    #
    # Some characters are not valid in identifiers though they don't appear to have a syntactical meaning either:
    # - brackets: ()
    # - symbols: !&
    #
    # Some characters are valid in identifiers but are displayed in some special fashion:
    # - localisation command marker: $ (e.g. “$COUNTRY_ADJ$”)
    # - string substitution within or without double quotes e.g. `text_add = { %2% }`.
    # - colouring: § (e.g. “§Bblue text§!”)
    # - game currency: ¤
    # - indent: £
    # - rebel flag: @
    #
    # We ignore control characters.

    token syntax-char { <[# " = {} ; \s]> }

    token identifier-char {
        <[0] # Start enumeration

            ## ASCII subset
            # brackets
            + [<>\[\]]
            # punctuation and separators
            + ['\-./:?_|]
            # misc. symbols
            + [%*+@^`~]
            # alphanumerical
            + [0..9A..Za..z]

            ## Windows-1252 extended characters
            # extra letters
            + [Œœµ]
            # letters with diacritics, uppercase & lowercase
            + [ŠŽŸÀÁÂÃÄÅÆÇÈÉÊËÌÍÎÏÐÑÒÓÔÕÖØÙÚÛÜÝÞ]
            + [šžÿàáâãäåæçèéêëìíîïðñòóôõöøùúûüýþß]
            # diacritics
            + [ˆ˜¨¯´¸]
            # punctuation
            + […•–—¡·¿]
            # quote marks
            + [‚‘’„“”‹›«»]
            # currency signs
            + [€ƒ¢£¤¥]
            # superscript symbols
            + [ª°²³¹º]
            # mathematical symbols
            + [‰¬±¼½¾×÷]
            # misc. symbols
            + [†‡™¦§©®¶]
        >
    }
}

#| Enable L<Match> to produce context information, for the purpose of human-friendly reports.
role Contextualising[\context-info = %(:3before, :3after, :120anchor-length)] {
    #| Produce a source L<Context>, using C<self> as an anchor.
    method context(
        Styles:D :$styles!,                  #= styling to use
        Bool :$focus-anchor,                 #=[ by default the anchor uses highlight styles, this sets it to use focus
                                                 instead
                                             ]
        Bool :$preserve-trailing-whitespace, #=[ preserve trailing whitespace from the C<self> anchor (useful e.g. when
                                                 the report is about that whitespace)
                                             ]
        --> Context:D
    ) {
        my grammar Whitespace does Scaffolding {
            # break self-referential knot that would otherwise be redundant
            method catch-non-standard-comment-header() {}
        }

        my (\target, \pos, \chars)   = do with self { .target, .pos, .chars };
        my (\anchor, \trail) = do if not $preserve-trailing-whitespace {
            self.Str.split(/ <.ws=.Whitespace::ws> $ /, 2, :v)
        } else {
            self.Str, ""
        }

        my \accepted = target.substr(0, pos - chars);
        my \rejected = trail ~ target.substr(pos);
        my \sep      = accepted.ends-with("\n") ?? "\n" !! "";
        # N.b. zero if and only if `pos` is zero, which is the case when matching the very first character or when
        # parsing fails
        my $line     = accepted.lines.elems;
        my $before   = accepted.lines[((* - context-info<before>) max 0) .. *];
        my \after    = rejected.lines[0 .. context-info<after>]:v;

        my \non-blank = $before.first(none(/ ^ \h* $ /), :k); # don't use Whitespace because comments are
                                                              # useful for establishing context
        $before = $before[non-blank andthen $_ .. * orelse Empty];

        my &style-anchor = do if $focus-anchor {
            sub focus-anchor(Str:D $_) { $styles.code-focus($_) }
        } else {
            sub highlight-anchor(Str:D $_) { $styles.code-highlight($_) }
        }

        my \styled-truncated-anchor = do if anchor.chars <= context-info<anchor-length> {
            style-anchor(anchor)
        } else {
            style-anchor(anchor.substr(0, context-info<anchor-length>)) ~ $styles.unimportant("…\n" ~ "⋯✂⋯" x 9)
        }

        $line => (
            $styles.code($before.join("\n")),
            $styles.code(sep),
            styled-truncated-anchor,
            $styles.code(after.join("\n")),
        ).join
    }

    #| The fragment of the line immediately preceding the current match.
    method preceding($_: --> Str:D) {
        .target.substr(0, .pos - .chars).lines[*-1]
    }
}

#| Base PDS script grammar. Handles everything that is common to all PDS script, though not able to parse any kind of
#| file. For that latter purpose see specific inheriting grammars or L<PDS::Unstructured>.
#|
#| Inheriting grammars should conform to the soup protocol if they want to play nice with L<PDS::soup>.
grammar Grammar does Contextualising does ErrorReporting does Remarking does Scaffolding {
    ## PDS script data types

    token text { <soup=.identifier> | <soup=.quoted-identifier> }
    # N.b. no «» boundary because some transliterated names (e.g. from Slavic languages) end in an apostrophe.
    token identifier        { <?after <.syntax-char>|^> <.identifier-char>+ <?before <.syntax-char>|$> }
    regex quoted-identifier { :r '"'~ '"' <-["]>* }

    # don't use quantifiers for LTM to kick in
    regex date              { :r « \d\d\d\d '.' \d\d? '.' \d\d? » }

    # N.b. overlaps with identifier
    token number            { <soup=.integer> | <soup=.decimal> }
    regex integer           { :r '-'? \d+ » }
    regex decimal           { :r '-'? [ \d+ ]? '.' \d+ » }

    regex yes-or-no         { :r:i « [ 'yes' | 'no' ] » }

    ## Helpers

    regex ok { <?> }

    # PDS script is case-insensitive
    # ??? Dear Raku, why must my parameter be optional especially if you seemingly always call the method with an
    # argument
    multi regex kw(Str $word?) { :r:i « $word » }

    ## Tokens

    token this          { <soup=.kw("this")> }
    token from          { <soup=.kw("from")> }
    token tag           { :i <!before "yes"> $<item>=(«<[a..z]><[a..z 0..9]>**2») }
    token tag-reference { <soup=.tag>|<soup=.this>|<soup=.from> }

    # In lieu of permutation parsing, expectation methods can be composed to validate parses. Expectations deal with
    # three grammar elements:
    #
    # - the anchor: a parse within the outermost element of interest, typically they key of key–value pair e.g.:
    #
    #       this_is_the_anchor = { …
    #
    # - the focus (self): some element of interest within the anchor, usually its immediate value block
    # - the target: the innermost element of interest, child of the focus, typically a key–value pair
    #
    # Of the three the anchor and the focus are definite elements that have already been successfully parsed or
    # validated. The target is the object of validation by the expectation. These three levels allow for writing helpful
    # diagnostics.
    #
    # These diagnostics are made customisable by allowing the caller to override message fragments.

    ## General expectations

    method prefer-none(
        Match:D \anchor, Str:D \target,
        Remark::Kind:D \default-kind = Remark::Opinion,
        :%kinds = %(),
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Pair:D       :$too-many           =
            ((%kinds{Inf} // default-kind) => { "$^a:element has an unexpected $^b:entry entry" }),
        --> Bool
    ) {
        given self{target} {
            when .elems != 0 {
                @extra-locs.append(.[1..*]);
                .[0].remark($too-many.key, $too-many.value.($element, $entry).chomp, :@extra-locs)
            }
            default          { True }
        }
    }

    method prefer-one(
        Match:D \anchor, Str:D \target,
        Remark::Kind:D \default-kind = Remark::Opinion,
        :%kinds = %(),
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Pair:D       :$missing            =
            ((%kinds{0} // default-kind)   => { "$^a:element is missing a valid $^b:entry entry" }),
        Pair:D       :$too-many           =
            ((%kinds{Inf} // default-kind) => { "$^a:element has more than one $^b:entry entry" }),
        --> Match #`(::?CLASS)
    ) {
        given self{target} {
            when .elems == 1 {
                .[0]
            }

            when .elems == 0 {
                anchor.remark($missing.key, $missing.value.($element, $entry).chomp, :@extra-locs)
            }

            default {
                @extra-locs.append(.[1..*]);
                .[0].remark($too-many.key, $too-many.value.($element, $entry).chomp, :@extra-locs)
            }
        }
    }

    method prefer-yes(
        Match:D \anchor, Str:D \target,
        Remark::Kind:D \default-kind = Remark::Opinion,
        :%kinds = %(),
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Str:D        :$expected           = $*STYLES.code-quote("{target} = {$*STYLES.code-focus("yes")}"),
        Pair:D   :$missing                =
            ((%kinds{0} // default-kind)   => { "$^a:element is missing a valid $^b:entry entry ($expected was expected)" }),
        Pair:D   :$too-many               =
            ((%kinds{Inf} // default-kind) => { "$^a:element has more than one $^b:entry entry" }),
        Pair:D   :$unexpected-no          =
            ((%kinds{1} // default-kind)   => { "$^b:entry entry of $^a:element set to $*STYLES.code("no") when $*STYLES.code-focus("yes") was expected" }),
        --> Bool:D
    ) {
        given $.prefer-one(anchor, target, :@extra-locs, :$element, :$entry, :$missing, :$too-many) {
            when !.<value>.&explicit-yes {
                (.<key> // $_).remark($unexpected-no.key, $unexpected-no.value.($element, $entry).chomp);
                False
            }

            default {
                True
            }
        }
    }

    method prefer-at-most-one(
        Match:D \anchor, Str:D \target,
        Remark::Kind:D \default-kind = Remark::Opinion,
        :%kinds = %(),
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Pair:D       :$missing            =
            ((%kinds{0} // default-kind) => { "$^a:element is missing a valid $^b:entry entry" }),
        Pair:D       :$too-many           =
        ((%kinds{Inf} // default-kind)   => { "$^a:element has more than one $^b:entry entry" }),
        --> #`(::?CLASS) List
    ) {
        given self{target} {
            when .elems > 1 {
                @extra-locs.append(.[1..*]);
                .[0].remark($too-many.key, $too-many.value.($element, $entry).chomp, :@extra-locs);
                ()
            }

            default {
                .[0..0]:v
            }
        }
    }

    method prefer-some(
        Match:D \anchor, Str:D \target,
        Remark::Kind:D \default-kind = Remark::Opinion,
        :%kinds = %(),
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Pair:D       :$missing            =
            ((%kinds{0} // default-kind) => { "$^a:element is missing a valid $^b:entry entry" }),
        --> #`(::?CLASS) List
    ) {
        given self{target} {
            when .elems == 0 {
                anchor.remark($missing.key, $missing.value.($element, $entry).chomp, :@extra-locs);
                ()
            }

            default {
                .List
            }
        }
    }

    ## Error expectations

    method expect-one(
        Match:D \anchor, Str:D \target,
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Callable:D   :$missing            = { "$^a:element is missing a valid $^b:entry entry" },
        Callable:D   :$too-many           = { "$^a:element has more than one $^b:entry entry" },
        --> Match #`(::?CLASS)
    ) {
        $.prefer-one(
            anchor, target, Remark::Error,
            :@extra-locs, :$element, :$entry, missing => Remark::Error => $missing, too-many => Remark::Error => $too-many,
        )
    }

    method expect-some(
        Match:D \anchor, Str:D \target,
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Callable:D   :$missing            = { "$^a:element is missing a valid $^b:entry entry" },
        --> #`(::?CLASS) List
    ) {
        self.prefer-some(
            anchor, target, Remark::Error,
            :@extra-locs, :$element, :$entry,
            missing => Remark::Error => $missing,
        )
    }

    method expect-yes(
        Match:D \anchor, Str:D \target,
        #`(::?CLASS) :@extra-locs is copy = (),
        Str:D        :$element            = $*STYLES.code(anchor.Str),
        Str:D        :$entry              = $*STYLES.code(target),
        Str:D        :$expected           = $*STYLES.code-quote("{target} = {$*STYLES.code-focus("yes")}"),
        Callable:D   :$missing            = { "$^a:element is missing a valid $^b:entry entry ($expected was expected)" },
        Callable:D   :$too-many           = { "$^a:element has more than one $^b:entry entry" },
        Callable:D   :$unexpected-no      = { "$^b:entry entry of $^a:element set to $*STYLES.code("no") when $*STYLES.code-focus("yes") was expected" },
        --> Bool
    ) {
        $.prefer-yes(
            anchor, target, Remark::Error,
            :@extra-locs, :$element, :$entry,
            missing       => Remark::Error => $missing,
            too-many      => Remark::Error => $too-many,
            unexpected-no => Remark::Error => $unexpected-no,
        )
    }
}

=begin pod

=head2 Additional Parse Roles

The semantic meaning of PDS script is not global but on a case-by-case basis. For instance files that describe events
are not expected to be structured the same as files that describe decisions. However when script files do end up with
similarities, we factor out the common parsing code into reusable roles.

=end pod

#| Parse an RGB color spec: C<color = { 60 120 180 }>.
role Color {
    rule color {
        <key=.kw('color')> '=' '{' ~ '}' <value=.color-spec>
    }

    rule color-spec {
        | @<color-values>=(<.hex-rgb> ** 3)
        | @<color-values>=(<.dec-rgb> ** 3)
    }

    regex hex-rgb {
        :r « [ 0 | 1 | \d**1..3 <?{ 0 <= $/.Int <= 255 }> ] <!before '.'> »
    }

    regex dec-rgb {
        :r « [ 0 | 1 | 0?'.'\d+ ] <!before '.'> »
    }
}

=head2 Parsers

#| Unstructured PDS script parser.
#|
#| Able to unsmartly parse script files N<L<PDS::Unstructured> has been designed & validated around Victoria 2 files
#| only>, though the result will be an unstructured soup.
#|
#| Remarks made during parsing can be accessed as the C<REMARKS> entry of the L<Associative> payload (see
#| L<Match::made>).
#|
#| For ease of convenience consider using L<PDS::parse> rather than the stock L<Grammar::parse> method common to all
#| grammars.
grammar Unstructured is Grammar {
    rule TOP(Styles:D :$styles!, Str :$source) {
        :my $*STYLES = $styles;
        :my $*SOURCE = $source;
        :my @*REMARKS;
        ^ @<entries>=<.entry>* $
        { remake($/, REMARKS => @*REMARKS) }
    }

    rule entry {
        | <soup=.pair>
        | <soup=.value>
    }

    ## Unstructured pair

    rule pair {
        <key=.simplex> '=' <value>
    }

    token value { <soup=.simplex> | <soup=.block> }

    # Simple values
    token simplex { <soup=.text> | <soup=.date> | <soup=.number> | <soup=.yes-or-no> }

    # Compound values
    rule block {
        '{' ~ '}' @<entries>=<.entry>*
    }
}

#| A structured grammar is one that deals in a particular subset of mod files, according to mod structure.
grammar Structured is Unstructured {
    my subset PathSuffix of Any where Str|List;

    #| For the purpose of parallel processing, structured grammars expose their topological level. This is with respect
    #| to the tree structure of game or mod files. Parsing should start with grammars at level zero with an empty
    #| universe, collecting the respective C<.made<RESULT>> results into an expanded universe. This will be fed into the
    #| parsing at level one, and so on.
    proto method topo-level(::?CLASS:D: --> Num:D)        { … }

    #| Path suffix for the directory inside the game or mod structure containing the files of interest to the grammar.
    proto method      where(::?CLASS:D: --> PathSuffix:D) { … }
    #| Smartmatch pattern for base names of interest to the grammar.
    proto method       what(::?CLASS:D: --> Any:D)        { … }
    #| Brief human-friendly description of what the grammar parses.
    proto method      descr(::?CLASS:D: --> Str:D)        { … }
}

=head2 AST Queries

# :ast export directives due to cross-module import+alias issues

our sub pair(\ast where Any:U|Match --> Bool:D) is export(:ast)
{ ast.defined && ast<key>.defined && ast<value>.defined }

# use when it’s not clear what a missing entry implies
our sub explicit-yes(\ast where Any:U|Match --> Bool:D) is export(:ast) { ast.defined && ast.fc eq 'yes'.fc }
our sub  explicit-no(\ast where Any:U|Match --> Bool:D) is export(:ast) { ast.defined && ast.fc eq  'no'.fc }

# use only when a missing entry implies ‘no’
our sub yes(\ast where Any:U|Match --> Bool:D) is export(:ast) {  ast.defined && ast<value>.&explicit-yes }
our sub  no(\ast where Any:U|Match --> Bool:D) is export(:ast) { !ast.defined || ast<value>.&explicit-no }

our sub kw(\ast where Any:U|Match --> Str:D) is export(:ast)
{ ast andthen .fc orelse "" }

=head2 Parse Functions & Actions

#| Parse some input against a L<PDS::Grammar>. Provides the following benefits over the stock L<Grammar::parse>:
#|
#| * fails with L<PDS::ParseError> (with appropriate information filled-in) if parsing was not succesful, or returns a
#|   L<Match>
#| * throws in case of a different error
our proto parse(
    Grammar \gram,                  #= L<PDS::Grammar> to perform the parsing
    Any:D \input,                   #= PDS script data
    Mu :$actions = Mu,              #= grammar actions
    Styles:D :$styles = Styles.new, #= styling, for source reports purposes
    Str :$source,                   #= name or shorthand designating the input
    :%universe,                     #= hash of results, from successive parses higher up the topological order
    *%,
    --> Match:D)
{ * }

#| Parse from a L<Str>.
multi parse(
    Grammar $gram is copy, #= L<PDS::Grammar> to perform the parsing
    Str:D() \input,        #= PDS script string to parse
    Mu :$actions = Mu,     #= grammar actions
    Styles:D :$styles,     #= styling, for source reports purposes
    Str :$source = input,  #= name or shorthand designating the input
    :%universe,            #= hash of results, from successive parses higher up the topological order
    --> Match:D)
{
    CATCH {
        when X::PDS::ParseError {
            .fail
        }
        default { .rethrow }
    }
    # seemingly required to stringify the top-level match or something to do with its attributes, don’t ask me
    $gram = $gram // $gram.new;
    my $args = \(:$styles, :$source, :%universe);
    $gram.parse(input, :$actions, :$args) // $gram.fatal-error("rejected by grammar {$gram.^name}", :$styles, :$source)
}

#| Parse from a file.
multi parse(
    Grammar \gram,                #= L<PDS::Grammar> to perform the parsing
    IO:D() \path,                 #= path to file
    Str:D :$enc = "windows-1252", #= file encoding
    Mu :$actions = Mu,            #= grammar actions
    Styles:D :$styles,            #= styling, for source reports purposes
    Str :$source = path.path,     #= name or shorthand designating the input
    :%universe,                   #= hash of results, from successive parses higher up the topological order
    --> Match:D
) {
    parse(gram, path.slurp(:$enc), :$actions, :$styles, :$source, :%universe)
}

#| Actions to turn the L<Match> produced by a L<PDS::Grammar> into into a tree-like array of items and pairs. See
#| L<PDS::soup>.
class Soup {
    # ??? Dear Raku, please explain ‘before’ and ‘after’ callbacks.
    method after($/)  {}
    method before($/) {}

    ## lexing bits

    method wb                  {}
    method comment($/)         {}
    method ws($/)              {}

    method syntax-char($/)     {}
    method identifier-char($/) {}

    ## common parsing

    method text($/)              { remake($/, SOUP => ~$/) }
    method identifier($/)        {}
    method quoted-identifier($/) {}

    method date($/)              { remake($/, SOUP => ~$/) }

    method number($/)            { remake($/, SOUP => $<soup>.made<SOUP>) }
    method integer($/)           { remake($/, SOUP => $/.Int) }
    method decimal($/)           { remake($/, SOUP => $/.Rat) }

    method yes-or-no($/)         { remake($/, SOUP => $/.substr(0, 1).fc eq 'y'.fc) }

    method ok($/)                {}

    method kw($/)                { remake($/, SOUP => ~$/) }

    ## extra parsing

    method color-spec            { remake($/, SOUP => @<color-values>».made<SOUP>) }

    ## soup protocol that grammars which inherit from L<PDS::Grammar> should conform to for these actions to work

    sub SOUP(Match:D $_) {
        # .made<SOUP> if already computed, rely on the soup protocol otherwise to construct it:
        #
        # - .<item> for single-item string matches
        # - .<soup> for passthrough or delegating single-item matches
        # - .<entries> for multi-item matches
        # - .<key> and .<value> for pair matches
        .made<SOUP> // do {
            when .<item>:exists    { .<item>.Str }
            when .<soup>:exists    { SOUP(.<soup>) }
            when .<entries>:exists { .<entries>».&SOUP }
            when .<key>:exists && (.<value>:exists) {
                Pair.new(SOUP(.<key>), SOUP(.<value>))
            }
            default {
                die "match does not honour the soup protocol:\n{.gist.indent(4)}"
            }
        }
    }

    method FALLBACK($name, $/) {
        remake($/, SOUP => SOUP($/))
    }
}

#| Turn PDS script into a tree-like array of items and pairs.
#|
#| Throws but does not fail, unlike L<PDS::Parse>.
our sub soup(
    Grammar \gram,                  #= L<PDS::Grammar> to perform the parsing
    Str:D() \input,                 #= PDS script string to parse
    Styles:D :$styles = Styles.new, #= styling, for source reports purposes
    Str :$source = input,           #= name or shorthand designating the input
    --> Array:D)
{
    parse(gram, input, actions => Soup, :$styles, :$source).made<SOUP> or []
}
