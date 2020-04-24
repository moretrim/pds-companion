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

#| Styles & typesetting.
unit class PDS::Styles is export;

our enum When « never always auto »;

has &.styler;

method new(::?CLASS:U: When:D \color = auto --> ::?CLASS:D) {
    my &styler = do if (Nil !=== try require Terminal::ANSIColor)
                        && (color eqv When::always
                            || (color eqv When::auto && $*OUT.t && $*ERR.t)) {
        my &colored = ::('Terminal::ANSIColor::EXPORT::DEFAULT::&colored');
        sub fancy(Str:D \text, Str:D \styles --> Str:D) {
            text.lines.map({ colored($_, styles) }).join("\n")
        }
    } else {
        sub plain(Str:D \text, Str:D $) { text }
    };

    self.bless(:&styler)
}

constant code-styles = #`(bold orange) "bold 255,204,00";

method style(::?CLASS:D: Str:D \text, Str:D \styles --> Str:D) {
    (&.styler)(text, styles)
}

method ellipsis(::?CLASS:D: Str:D :$extra-styles = "" --> Str:D) {
    (&.styler)("…", #`(grey) "96,96,96")
}

method code(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    (&.styler)(text.trim-trailing.chomp, (code-styles, $extra-styles).join(" "))
}

method highlight(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    (&.styler)(text.trim-trailing.chomp, (code-styles, $extra-styles).join(" "))
}

method attention(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    (&.styler)(text, ("cyan", $extra-styles).join(" "))
}

method important(::?CLASS:D: Str:D \text, Str:D :$extra-styles = "" --> Str:D) {
    (&.styler)(text, (#`(darker orange) "255,65,00", $extra-styles).join(" "))
}

role Stylish {
    has PDS::Styles:D $.styles = PDS::Styles.new;
}
