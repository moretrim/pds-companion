=begin COPYRIGHT
Copyright 2019 moretrim.

This file is part of PFH-Tools.

PFH-Tools is free software: you can redistribute it and/or modify
it under the terms of the GNU General Public License as published by
the Free Software Foundation, either version 3 of the License, or
(at your option) any later version.

PFH-Tools is distributed in the hope that it will be useful,
but WITHOUT ANY WARRANTY; without even the implied warranty of
MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
GNU General Public License for more details.

You should have received a copy of the GNU General Public License
along with PFH-Tools.  If not, see <https://www.gnu.org/licenses/>.
=end COPYRIGHT

#| Tools to help with modding Paradox Development Studio games.
unit module PDS;

use Grammar::ErrorReporting;
# no precompilation;
# use Grammar::Tracer;

use remake;

sub line-hint(Match:D $_, --> Int:D)
{
    my \parsed = .target.substr(0, .pos).trim-trailing;
    parsed.lines.elems
}

# Resort to a global because grammar rules don't capture whitespace, which is where we put comments.
my @COMMENT-REMARKS;

sub remark(Match:D $/, Str \message)
{
    my \line = line-hint($/);
    remake($/, remarks => ((line => message),))
}

sub format-remarks(Positional:D \remarks, --> Str:D)
{
    remarks.map(-> (:$key, :$value) { "on line $key: $value" }).join("\n")
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
        { remake($/, remarks => ()) }
    }

    # N.b. handling of non NL-terminated input
    token wb { <?after <.syntax-char>|^|$> }
    token comment {
        $<comment-header>=<[#;]>
        \V*
        [ \n\s* | $ ]
        { @COMMENT-REMARKS.push(line-hint($/) => "use of non-standard comment header ‘;’") if $<comment-header> eq ';' }
    }
    token ws { <|wb> \s* <comment>* { remake($/) } }

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
        { remake($/) }
    }

    # Specific entries

    rule color {
        'color' '=' '{' ~ '}' <color-spec>
        { remake($/) }
    }

    rule color-spec {
        | <hex-rgb> ** 3
        | <dec-rgb> ** 3
        { remake($/) }
    }

    rule hex-rgb {
        « [ 0 | 1 | \d**1..3 <?{ 0 <= $/.Int <= 255 }> ] »
        { remake($/) }
    }

    rule dec-rgb {
        « [ 0 | 1 | 0?'.'\d+ ] »
        { remake($/) }
    }

    # Generic pair

    rule pair   {
        <key=.simplex> '=' <value>
        { remake($/) }
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
        { remake($/) }
    }
}

our sub parse(Grammar \gram, IO:D(Cool:D) \path, Str:D :$enc = "windows-1252", --> Match:D)
{
    CATCH {
        default {
            # How do you decorate exceptions in Perl6?
            "While attempting to parse {path}".note;
            .rethrow
        }
    }
    gram.parse(path.slurp(:$enc))
}

our sub lint(Grammar \gram, IO:D(Cool:D) \path, Str:D :$enc = "windows-1252")
{
    @COMMENT-REMARKS = ();

    my \soup = parse(gram, path, :$enc);
    unless soup.defined {
        note "while attempting to parse {path}";
        return
    }

    my \remarks = |(soup.made<remarks>), |@COMMENT-REMARKS;
    if remarks {
        say "in {path}:\n{format-remarks(remarks).indent(4)}"
    }
}

sub pairify(Match:D $/, --> Pair:D)
{
    my $key = ~$<key><identifier>;
    with $<value><simplex> {
        $key => ~$_
    } else {
        $key => hashify($<value><complex><contents>)
    }
}

sub hashify(Positional:D $_, --> Hash:D)
{
    .map(&pairify).Hash
}

#| Turn the resulting L<Match> from a L<PDS> grammar into a list of hashes.
sub soup($/, --> Hash) is export
{
    $/ andthen hashify(@<entries>»<pair>) orelse Hash
}
