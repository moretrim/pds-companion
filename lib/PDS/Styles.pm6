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

#| Styles & typesetting.
unit class PDS::Styles is export;

our enum When « never always auto »;

# stylistic palette

constant palette-wheel = (
    ## Primary accents
    # top to bottom: in rough order of R–Y–G–C–B–M color wheel
    # across: tint/tone/shade
    #
    # Of the lot, yellow-accent0 & red-accent0 (in that order) really strike out. Despite looking
    # pastelish, they still come off more saturated than the rest. This is fine as long as they are
    # semantically used for attention grabbing.
    #
    # The rest look pastel enough to come off as soothing.
    #
    # This is all designed for use on dark backgrounds. Light backgrounds have not been considered.

    # Reds
    red-accent0 => "208,51,41", # "red",

    # Yellows
    yellow-accent0 => #`(pale yellow) "255,238,64",

    # Blues and greens
    bluegreen-accent0 => #`(blue–green, trending greenish) "77,145,132",
    bluegreen-accent1 => #`(blue–green, trending deep blue) "8,110,144",
        bluegreen-shaded-accent1 => #`(pale blue shade) "141,158,198",

    # Magentas
    magenta-accent0 => #`(violet–pink) "255,136,220",

    ## Secondaries

    grey0 => "96,96,96",
);

constant palette = palette-wheel.Hash;

# semantic palettes

=head2 Inline styles

#| To make things stand out.
constant highlight-styles   = "underline";
#| To put things into full focus.
constant focus-styles       = "underline inverse";
#| For PDS script.
constant code-styles        = "bold {palette<bluegreen-shaded-accent1>}";
#| For mild emphasis. “Bring to attention.”
constant attention-styles   = palette<yellow-accent0>;
#| For stronger emphasis.
constant important-styles   = palette<magenta-accent0>;
#| For strongest emphasis.
constant alert-styles       = palette<red-accent0>;
#| For de-emphasis.
constant unimportant-styles = palette<grey0>;
#| For a path.
constant path-styles        = palette<bluegreen-accent1>;

=head2 Element styles

constant header-styles = "bold {palette<bluegreen-accent0>}";

#| Brackets, according to content, according to fanciness, opener+closer.
constant brackets = %(
    # content => (fancy,    plain)
    none      => (('', ''), ('', '')),
    header    => (<❯ ❮>,    <❯ ❮>),
    text      => (<‘ ’>,    <‘ ’>),
    path      => (('', ''), <‘ ’>),
    code      => (<｢ ｣>,    <｢ ｣>),
);

has When:D $.initialiser = auto;
has        &.styler;
has        &.quoter;

method new(::?CLASS:U: When:D \color = auto --> ::?CLASS:D) {
    my Bool:D \fancy = (Nil !=== try require Terminal::ANSIColor)
                       && (color eqv When::always
                           || (color eqv When::auto && $*OUT.t && $*ERR.t));

    my (&styler, &quoter) = do if fancy {
        my &colored = ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored');
        (
            sub fancy(
                Str:D $_,
                Str:D \styles,
                --> Str:D
            ) {
                (
                    .lines.map({ colored($_, styles) }).join("\n"),
                    .ends-with("\n") ?? "\n" !! Empty,
                ).join
            },

            sub colour-quote(
                Str:D $_, Str:D \styles,
                :$brackets = ((unimportant-styles) => brackets<text>),
                --> Str:D
            ) {
                (
                    fancy($brackets.value[0][0], $brackets.key),
                    .lines.map({ colored($_, styles) }).join("\n"),
                    .ends-with("\n") ?? "\n" !! Empty,
                    fancy($brackets.value[0][1], $brackets.key),
                ).join
            },
        )
    } else {
        (
            sub plain(Str:D \text, Str:D $ --> Str:D)
            { text },

            sub plain-quote(
                Str:D \text, Str:D $,
                :$brackets = ((unimportant-styles) => brackets<text>),
                --> Str:D
            ) {
                $brackets.value[1][0] ~ text ~ $brackets.value[1][1]
            },
        )
    };

    self.bless(initialiser => color, :&styler, :&quoter)
}

method perl(::?CLASS: --> Str:D) {
    (
        $.^name,
        do if $.defined {
            my $initialiser = do given $.initialiser {
                # Because L<auto> is the default and L<never> is typically used in tests, we ensure
                # those two are aligned. This helps testers quickly scan the output of tests when
                # looking for a difference.
                when auto  { " auto" }
                when never { "never" }
                default    { .Str }
            }
            ".new($initialiser)"
        },
    ).join
}

method palette-demo(::?CLASS:D: --> Str:D) {
    my \first-column = palette-wheel.map(*.key.chars).max;
    qq:to«END».chomp
    {"colour".fmt("%{first-column}s")}: normal\t\t\t\tbold\t\t\t\titalic
    {
        palette-wheel.map(-> \color {
            &.styler.(qq:to«END».chomp, color.value)
            {color.key.fmt("%{first-column}s")}: {
                (
                    &.styler.(
                        "the quick brown fox",
                        "{color.value} $_"
                    ) for "", "bold", "italic"
                ).join(" ")
            }
            END
        }).join("\n")
    }
    END
}

method style(::?CLASS:D: Str:D \text, Str:D \styles --> Str:D) {
    &.styler.(text, styles)
}

method quote(::?CLASS:D: Str:D \text, Str:D \styles --> Str:D) {
    &.quoter.(text, styles)
}

method quote-path(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<path>),
    --> Str:D
) {
    &.quoter.(text, (path-styles, $extra-styles).join(" "), :$brackets)
}

method ellipsis(::?CLASS:D: Str:D :$extra-styles = "" --> Str:D) {
    &.styler.("…", (unimportant-styles, $extra-styles).join(" "))
}

method code(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (code-styles, $extra-styles).join(" "))
}

method code-quote(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<code>),
    --> Str:D
) {
    &.quoter.(text, (code-styles, $extra-styles).join(" "), :$brackets)
}

method code-highlight(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    self.code(text, extra-styles => highlight-styles)
}

method code-highlight-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    self.code-quote(text, extra-styles => highlight-styles)
}

method code-focus(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    self.code(text, extra-styles => focus-styles)
}

method code-focus-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    self.code-quote(text, extra-styles => focus-styles)
}

method attention(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (attention-styles, $extra-styles).join(" "))
}

method attention-quote(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<text>),
    --> Str:D
) {
    &.quoter.(text, (attention-styles, $extra-styles).join(" "), :$brackets)
}

method important(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (important-styles, $extra-styles).join(" "))
}

method important-quote(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<text>),
    --> Str:D
) {
    &.quoter.(text, (important-styles, $extra-styles).join(" "), :$brackets)
}

method alert(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (alert-styles, $extra-styles).join(" "))
}

method alert-quote(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<text>),
    --> Str:D
) {
    &.quoter.(text, (alert-styles, $extra-styles).join(" "), :$brackets)
}

method unimportant(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (unimportant-styles, $extra-styles).join(" "))
}

method unimportant-quote(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((unimportant-styles) => brackets<text>),
    --> Str:D
) {
    &.quoter.(text, (unimportant-styles, $extra-styles).join(" "), :$brackets)
}

method header(
    ::?CLASS:D: Str:D \text,
    Str:D :$extra-styles = "",
    Pair:D :$brackets = ((header-styles) => brackets<header>),
    --> Str:D
) {
    &.quoter.(text, (header-styles, $extra-styles).join(" "), :$brackets)
}

role Stylish {
    has PDS::Styles:D $.styles = PDS::Styles.new;
}

=head2 Conventional messages

#| Format styled, structured warning.
method format-warning(Str:D \msg --> Str:D)
{
    constant header = "WARNING";
    my \lines = msg.split("\n");

    if lines.elems <= 1 {
        my \styled-header       = $.alert("‣ {header}");

        "{styled-header} {lines[0]}"
    } else {
        my \styled-header       = $.alert("┌ {header}");
        my \styled-continuation = $.alert("│ ");
        my \styled-closer       = $.alert("└ ");

        qq:to«END».chomp
        {styled-header} {lines[0]}{lines[1 ..^ * - 1].map("\n" ~ styled-continuation ~ *).join}
        {styled-closer}{lines[* - 1]}
        END
    }
}
