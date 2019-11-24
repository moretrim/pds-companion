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

#| Tools to help with modding Paradox Development Studio games.
unit module PDS;

use Grammar::ErrorReporting;

use remake;

=head2 Error Reporting

constant &fancy = do if $*OUT.t && (Nil !=== try require Terminal::ANSIColor) {
    ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored')
} else {
    sub plain(\text, $) { text }
};

#| Base exception for all parsing errors.
#|
#| Thrown when a L<PDS::Grammar> reports an error.
class GLOBAL::X::PDS::ParseError is X::Grammar::ParseError {
    # from X::Grammar::ParseError, to make them mutable
    has $.description      is rw;
    has $.line             is rw;
    has $.msg              is rw;
    has $.error-position   is rw;
    has $.context-string   is rw;
    has $.goal             is rw;

    has Str  $.source      is rw;
    has Pair @.decorations is rw;

    method message(--> Str:D) {
        my \report = callsame;
        my \source = ($.source andthen "‘{fancy($_, "cyan")}’" orelse fancy("<unspecified>", "red"));
        my \decoration-header = @.decorations ?? ' with the following extra information:' !! '';
        qq:to«END».chomp;
        While parsing {source}{decoration-header}{ @.decorations.map({ "\n    {.key} => {.value}" }) }
        {report.trim}
        END
    }
}

#| Role for easily reporting parsing errors.
role ErrorReporting does Grammar::ErrorReporting {
    #| Throw an L<X::PDS::ParseError>.
    method error(
        ::?CLASS:D:
        $msg,          #= reason for failure to parse
        :$goal,        #= (unused)
        **@decorations #= additional information
    ) {
        # ideally
        # try nextwith($msg, :$goal);

        # meta-hack, requires disabling precompilation
        # try Grammar::ErrorReporting.^lookup('error')(self, $msg, :$goal);

        # instead, we clone and imbue with the base role
        try (Match.new(
            :$.hash,
            :$.list,
            :$.from,
            :$.orig,
            :$.pos,
            :$.made,
        ) but Grammar::ErrorReporting).error($msg, :$goal);

        given $! {
            when X::Grammar::ParseError {
                X::PDS::ParseError.new(
                    description => .description,
                    line => .line,
                    msg => .msg,
                    target => .target,
                    error-position => .error-position,
                    context-string => .context-string,
                    goal => .goal,
                    :@decorations,
                ).throw
            }

            default {
                .throw
            }
        }
    }
}

=head2 Remarks

#| When something is not quite a parsing error that needs to be reported through L<ErrorReporting::error>, a grammar can
#| instead report it as a remark. This should only happen for things that:
#|
#| - are noncritical, i.e. does not involve malformed script that would be rejected by the game
#| - cannot or should not be handled in parse actions
class Remark {
    #| A L<Remark> can have several kinds. They are:
    #|
    #| - C<Opinion>: Hints to help write consistent PDS script. As suggested by the name, this reflects this author's
    #|   opinions and may not suit everybody. This kind of remarks is mostly intended for new script, as it can be very
    #|   noisy when run on already-existing script.
    enum Kind «Opinion»;

    has Int $.line;
    has Set $.kinds;
    has Str $.message;

    method WHICH(--> ValueObjAt:D) {
        ValueObjAt.new((.^name, $.line, $.kinds.WHICH, $.message).join("|")) given self
    }
}

#| Role for easily storing remarks.
role Remarking {
    method line-hint(--> Int:D) {
        my \parsed = self.target.substr(0, self.pos).trim-trailing;
        parsed.lines.elems
    }

    multi method remark(Set:D[Remark::Kind:D] $kinds where { so $_ }, Str:D $message) {
        @*REMARKS.push(Remark.new(line => self.line-hint, :$kinds, :$message));
        Nil
    }

    multi method remark(Remark::Kind:D $kind, Str:D $message) {
        self.remark(set($kind), $message)
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
            .remark(Remark::Opinion, "use of non-standard comment header ‘;’")
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

#| Base PDS script grammar. Handles everything that is common to all PDS script, though not able to parse any kind of
#| file. For that latter purpose see specific inheriting grammars or L<PDS::Unstructured>.
#|
#| Inheriting grammars should conform to the soup protocol if they want to play nice with L<PDS::soup>.
grammar Grammar does ErrorReporting does Remarking does Scaffolding {
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
    regex kw(Str:D \word) { :r:i « $(word) » }
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
    rule TOP {
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

=head2 AST Queries

# :ast export directives due to cross-module import+alias issues

our sub kw-yes(\ast where Any:U|Match --> Bool:D) is export(:ast) { ast.defined && ast.fc eq 'yes'.fc }
our sub  kw-no(\ast where Any:U|Match --> Bool:D) is export(:ast) { ast.defined && ast.fc eq  'no'.fc }

# for things of the style `is_triggered_only = yes`
our sub yes(\ast where Any:U|Match --> Bool:D) is export(:ast) { ast.defined && ast<value>.&kw-yes }

=head2 Parse Functions & Actions

#| Parse some input against a L<PDS::Grammar>. Provides the following benefits over the stock L<Grammar::parse>:
#|
#| * fails with L<PDS::ParseError> (with appropriate information filled-in) if parsing was not succesful, or returns a
#|   L<Match>
#| * throws in case of a different error
our proto parse(Grammar \gram, Any:D \input, Mu :$actions = Mu --> Match:D)
{ * }

#| Parse from a L<Str>.
multi parse(Grammar $gram is copy, Str:D() \input, Mu :$actions = Mu --> Match:D)
{
    CATCH {
        when X::PDS::ParseError {
            .source = "<string>";
            .fail
        }
        default { .rethrow }
    }
    $gram = $gram // $gram.new;
    $gram.parse(input, :$actions)
        // $gram.error("rejected by grammar {$gram.^name}.")
}

#| Parse from a file.
multi parse(
    Grammar \gram,
    IO:D() \path,                 #= path to file
    Str:D :$enc = "windows-1252", #= file encoding
    Mu :$actions = Mu
    --> Match:D
) {
    CATCH {
        when X::PDS::ParseError {
            .source = path.Str;
            .fail
        }
        default { .rethrow }
    }
    parse(gram, path.slurp(:$enc), :$actions).self
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
        # - .<soup> for passthrough or delegating single-item matches
        # - .<entries> for multi-item matches
        # - .<key> and .<value> for pair matches
        .made<SOUP> // do {
            when .<soup>:exists    { SOUP(.<soup>) }
            when .<entries>:exists { .<entries>».&SOUP }
            when .<key>:exists && (.<value>:exists) {
                Pair.new(SOUP(.<key>), SOUP(.<value>))
            }
            default {
                die "match does not honour the soup protocol"
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
our sub soup(Grammar \gram, Str:D \input --> Array:D) is export
{
    parse(gram, input, actions => Soup).made<SOUP> or []
}
