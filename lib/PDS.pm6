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

sub line-hint(Match:D $_ --> Int:D)
{
    my \parsed = .target.substr(0, .pos).trim-trailing;
    parsed.lines.elems
}

class Remarks {
    has Pair @.commment-remarks;

    method comment($/) {
        if $<comment-header> eq ';' {
            @.comment-ramkers.push(line-hint($/) => "use of non-standard comment header ‘;’")
        }
    }

    method format-remarks(--> Str:D) {
        @.comment-remarks.unique.map(-> (:$key, :$value) { "on line $key: $value" }).join("\n")
    }
}

#| Base PDS script grammar.
#|
#| Able to unsmartly parse script files N<L<PDS::Grammar> has been designed & validated around Victoria 2 files only>,
#| though the result will be an unstructured soup. Its main purpose is to be subclassed and reused in order to perform
#| more structured parsing.
#|
#| Remarks made during parsing can be accessed as the C<remarks> entry of the L<Associative> payload (see
#| L<Match::made>).
#|
#| For ease of convenience consider using L<PDS::parse> rather than the stock L<Grammar::parse> method common to all
#| grammars.
grammar Grammar does ErrorReporting {
    rule TOP {
        ^ @<entries>=<.entry>* $
    }

    token ok { <?> }

    # N.b. handling of non NL-terminated input
    token wb { <?after <.syntax-char>|^|$> }
    token comment {
        $<comment-header>=<[#;]>
        \V*
        [ \n\s* | $ ]
    }
    token ws { <|wb> \s* <comment>* }

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

    rule entry {
        | <soup=.pair>
        | <soup=.value>
        | <soup=.color>
    }

    ## Specific entries

    ### Colours

    rule color {
        $<key>=('color') '=' '{' ~ '}' <value=.color-spec>
    }

    rule color-spec {
        | @<color-values>=(<.hex-rgb> ** 3)
        | @<color-values>=(<.dec-rgb> ** 3)
    }

    rule hex-rgb {
        « [ 0 | 1 | \d**1..3 <?{ 0 <= $/.Int <= 255 }> ] »
    }

    rule dec-rgb {
        « [ 0 | 1 | 0?'.'\d+ ] »
    }

    ## Generic pair

    rule pair {
        <key=.simplex> '=' <value>
    }

    token value { <soup=.simplex> | <soup=.block> }

    ## Simple values

    # N.b. as opposed to a compound value aka a block
    token simplex { <soup=.text> | <soup=.date> | <soup=.number> | <soup=.yes-or-no> }

    token text { <soup=.identifier> | <soup=.quoted-identifier> }
    # N.b. no «» boundary because some transliterated names (e.g. from Slavic languages) end in an apostrophe.
    token identifier        { <?after <.syntax-char>|^> <.identifier-char>+ <?before <.syntax-char>|$> }
    token quoted-identifier { '"' ~ '"' <-["]>* }
    # don't use quantifiers for LTM to kick in
    token date              { « \d\d\d\d '.' \d\d? '.' \d\d? » }
    # N.b. overlaps with identifier
    token number            { <soup=.integer> | <soup=.decimal> }
    token integer           { '-'? \d+ » }
    token decimal           { '-'? [ \d+ ]? '.' \d+ » }
    token yes-or-no         { « [ 'yes' | 'no' ] » }

    ## Compound values

    rule block {
        '{' ~ '}'
        @<entries>=<.entry>*
    }
}

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

class Soup {
    # ??? Dear Perl 6, please explain ‘before’ and ‘after’ callbacks.
    method after($/) {}
    method before($/) {}

    method TOP($/) {
        make(@<entries>».made)
    }

    method ok($/) {}

    method comment($/) {}
    method ws($/)      {}

    method syntax-char($/)     {}
    method identifier-char($/) {}

    method color-spec($/) {
        make(@<color-values>».made)
    }

    method hex-rgb($/) { make($/.Int) }
    method dec-rbg($/) { make($/.Rat) }

    method text($/)              { make(~$/) }
    method identifier($/)        {}
    method quoted-identifier($/) {}
    method date($/)              { make(~$/) }
    method integer($/)           { make($/.Int) }
    method decimal($/)           { make($/.Rat) }
    method yes-or-no($/)         { make(~$/ eq 'yes') }

    method FALLBACK($name, $/) {
        given $/ {
            when .<soup>:exists    { make(.<soup>.made) }
            when .<entries>:exists { make(.<entries>».made) }
            when .<key>:exists && (.<value>:exists) {
                make(Pair.new(.<key>.made // .<key>.Str, .<value>.made // .<value>.Str))
            }
        }
    }

    # These are not strictly speaking necessary thanks to FALLBACK, but do speed up the parsing by avoiding the generic
    # handling machinery.

    method entry($/)   { make($<soup>.made) }
    method pair($/)    { make($<key>.made => $<value>.made) }
    method value($/)   { make($<soup>.made) }
    method simplex($/) { make($<soup>.made) }
    method number($/)  { make($<soup>.made) }
    method block($/)   { make(@<entries>».made) }
}

#| Turn PDS script into a tree-like array of items and pairs.
#|
#| Throws but does not fail, unlike L<PDS::Parse>.
our sub soup(Grammar \gram, Str:D \input --> Array:D) is export
{
    parse(gram, input, actions => Soup).made
}
