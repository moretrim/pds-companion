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

#| Styles & typesetting.
unit class PDS::Styles is export;

our enum When « never always auto »;

#| To make things stand out.
constant highlight-styles   = "underline";
#| To put things into full focus.
constant focus-styles       = "underline inverse";
#| For PDS script.
constant code-styles        = #`(bold, blue–green shade) "bold 141,158,198";
#| For mild emphasis. “Bring to attention.”
constant attention-styles   = #`(pale yellow) "255,238,64";
#| For stronger emphasis.
constant important-styles   = #`(violet–pink) "255,136,220";
#| For strongest emphasis.
constant alert-styles       = "bold red";
#| For de-emphasis.
constant unimportant-styles = #`(grey) "96,96,96";
#| For a path.
constant path-styles        = "blue";

#| Brackets, according to content, according to fanciness, opener+closer.
constant brackets = %(
    # content => (fancy,    plain)
    text      => (<‘ ’>,    <‘ ’>),
    path      => ((''; ''), <‘ ’>),
    code      => (<｢ ｣>,    <｢ ｣>),
);

has &.styler;
has &.quoter;

method new(::?CLASS:U: When:D \color = auto --> ::?CLASS:D) {
    my Bool:D \fancy = (Nil !=== try require Terminal::ANSIColor)
                       && (color eqv When::always
                           || (color eqv When::auto && $*OUT.t && $*ERR.t));

    my (&styler, &quoter) = do if fancy {
        my &colored = ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored');
        (
            sub fancy(Str:D $_, Str:D \styles --> Str:D) {
                (
                    .lines.map({ colored($_, styles) }).join("\n"),
                    .ends-with("\n") ?? "\n" !! Empty,
                ).join
            },
            sub colour-quote(Str:D $_, Str:D \styles, :$brackets = brackets<text> --> Str:D) {
                (
                    fancy($brackets[0][0], unimportant-styles),
                    .lines.map({ colored($_, styles) }).join("\n"),
                    .ends-with("\n") ?? "\n" !! Empty,
                    fancy($brackets[0][1], unimportant-styles),
                ).join
            },
        )
    } else {
        (
            sub plain(Str:D \text, Str:D $ --> Str:D)
            { text },
            sub plain-quote(Str:D \text, Str:D $, :$brackets = brackets<text> --> Str:D)
            { $brackets[1][0] ~ text ~ $brackets[1][1] },
        )
    };

    self.bless(:&styler, :&quoter)
}

method style(::?CLASS:D: Str:D \text, Str:D \styles --> Str:D) {
    &.styler.(text, styles)
}

method quote(::?CLASS:D: Str:D \text, Str:D \styles --> Str:D) {
    &.quoter.(text, styles)
}

method quote-path(::?CLASS:D: Str:D \text, Str:D $extra-styles = "" --> Str:D) {
    &.quoter.(text, (path-styles, $extra-styles).join(" "), brackets => brackets<path>)
}

method ellipsis(::?CLASS:D: Str:D :$extra-styles = "" --> Str:D) {
    &.styler.("…", (unimportant-styles, $extra-styles).join(" "))
}

method code(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (code-styles, $extra-styles).join(" "))
}

method code-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.quoter.(text, (code-styles, $extra-styles).join(" "), brackets => brackets<code>)
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

method attention-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.quoter.(text, (attention-styles, $extra-styles).join(" "))
}

method important(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (important-styles, $extra-styles).join(" "))
}

method important-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.quoter.(text, (important-styles, $extra-styles).join(" "))
}

method alert(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (alert-styles, $extra-styles).join(" "))
}

method alert-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.quoter.(text, (alert-styles, $extra-styles).join(" "))
}

method unimportant(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.styler.(text, (unimportant-styles, $extra-styles).join(" "))
}

method unimportant-quote(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    &.quoter.(text, (unimportant-styles, $extra-styles).join(" "))
}

role Stylish {
    has PDS::Styles:D $.styles = PDS::Styles.new;
}
