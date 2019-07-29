=begin COPYRIGHT
Copyright © 2019 moretrim.

This file is part of PFH-Tools.

PFH-Tools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License version 3 as
published by the Free Software Foundation.

PFH-Tools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PFH-Tools.  If not, see <https://www.gnu.org/licenses/gpl-3.0.html>.
=end COPYRIGHT

#| Tools to help with modding Paradox Development Studio games.
unit module PDS;

use Grammar::ErrorReporting;
# no precompilation;
# use Grammar::Tracer;

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

#| A base for PDS script grammars.
#|
#| It is able to unsmartly parse most PDS script files, though the result will be an unstructured soup. Its main purpose
#| is to be subclassed and reused in order to perform more structured parsing.
#|
#| Remarks made during parsing can be accessed as the C<remarks> entry of the L<Associative> payload (see
#| L<Match::made>).
grammar Grammar does Grammar::ErrorReporting {
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
    # - symbols: !$%&
    #
    # Some characters are valid in identifiers but are displayed in some special fashion:
    # - localisation command marker: $ (e.g. “$COUNTRY_ADJ$”)
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
            + [*+@^`~]
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

our sub parse(Grammar \gram, IO:D(Cool:D) \path, Mu :$actions = Mu, Str:D :$enc = "windows-1252" --> Match:D)
{
    CATCH {
        default {
            # How do you decorate exceptions in Perl6?
            "While attempting to parse {path}".note;
            .rethrow
        }
    }
    gram.parse(path.slurp(:$enc), :$actions)
        // die "Input rejected by grammar {gram.^name}."
}

our sub lint(Grammar \gram, IO:D(Cool:D) \path, Str:D :$enc = "windows-1252")
{
    my Remarks $actions = Remarks.new;
    my \soup = parse(gram, path, :$actions, :$enc);
    unless soup.defined {
        note "While attempting to parse {path}";
        return
    }

    if $actions.comment-remarks {
        $actions.format-remarks().say;
    }
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
    # handling.

    method entry($/)   { make($<soup>.made) }
    method pair($/)    { make($<key>.made => $<value>.made) }
    method value($/)   { make($<soup>.made) }
    method simplex($/) { make($<soup>.made) }
    method number($/)  { make($<soup>.made) }
    method block($/)   { make(@<entries>».made) }
}

#| Turn PDS script into a tree-like array of items and pairs.
our sub soup(Grammar \gram, Str:D \input --> Array) is export
{
    gram.parse(input, actions => Soup).made
}
