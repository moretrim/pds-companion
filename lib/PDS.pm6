=begin COPYRIGHT
© Copyright 2019 moretrim.

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

sub line-hint(Match:D $_, --> Int:D)
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
        | <pair>
        | <value>
        | <color>
    }

    # Specific entries

    rule color {
        'color' '=' '{' ~ '}' <color-spec>
    }

    rule color-spec {
        | <hex-rgb> ** 3
        | <dec-rgb> ** 3
    }

    rule hex-rgb {
        « [ 0 | 1 | \d**1..3 <?{ 0 <= $/.Int <= 255 }> ] »
    }

    rule dec-rgb {
        « [ 0 | 1 | 0?'.'\d+ ] »
    }

    # Generic pair

    rule pair   {
        <key=.simplex> '=' <value>
    }

    token value { <simplex> | <complex=.block> }

    ## Simple values

    # N.b. as opposed to a compound value aka a block
    token simplex { <identifier> | <identifier=.quoted-identifier> | <date> | <number> }

    # N.b. no «» boundary because some transliterated names (e.g. from Slavic languages) end in an apostrophe.
    token identifier        { <?after <.syntax-char>|^> <.identifier-char>+ <?before <.syntax-char>|$> }
    token quoted-identifier { '"' ~ '"' <-["]>* }
    # N.b. overlaps with identifier
    token number            { '-'? [ \d+ ['.' \d+]? | '.' \d+ ] » }
    # don't use quantifiers for LTM to kick in
    token date              { « \d\d\d\d '.' \d\d? '.' \d\d? » }

    ## Compound values

    rule block {
        '{' ~ '}'
        @<contents>=<.entry>*
    }
}

our sub parse(Grammar \gram, IO:D(Cool:D) \path, Mu :$actions = Mu, Str:D :$enc = "windows-1252", --> Match:D)
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
    method TOP($/) {
        make(@<entries>».made)
    }

    method entry($/) {
        make($/.caps[0].value.made)
    }

    method color($/) {
        make(color => $<color-spec>.made)
    }

    method color-spec($/) {
        make((@<hex-rgb> // @<dec-rbg>)».made)
    }

    method hex-rgb($/) { make($/.Int) }
    method dec-rbg($/) { make($/.Num) }

    method pair($/) {
        make($<key>.made => $<value>.made)
    }

    method value($/) {
        make(($<simplex> // $<complex>).made)
    }

    method simplex($/) { make($/.made // ~$/) }
    method number($/) { make($/.Num) }

    method block($/) { make(@<contents>».made) }
}

#| Turn PDS script into a tree-like array of items and pairs.
our sub soup(Grammar \gram, Str:D \input, --> Array) is export
{
    gram.parse(input, actions => Soup).made
}
