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

use PDS::Styles;
use PDS;

#| Tools to deal with a mod structure.
unit class PDS::Mod does Styles::Stylish;

#| Mod base path, under which all mod files live.
has IO:D $.base = ".".IO;

=head2 Computing mod files

#| Compute files of interest from directories, files, & valid extensions.
our sub files-from-absolute-paths(
    Positional:D \paths, #= mod paths to turn into file paths
    Positional:D \exts,  #= valid file extensions
    #`( --> ?? what’s the type for coroutines again )
) {
    my @pending = paths.map(*.IO);
    while @pending {
        with @pending.shift {
            when :d { @pending.append(.dir) }
            .cleanup.take when .extension(:parts(^Inf)).fc ~~ *.ends-with(exts.any);
        }
    }
}

#| Compute mod files of interest from directories, files, & valid extensions.
method files-from-paths(
    Positional:D \paths, #= mod paths to turn into file paths
    Positional:D \exts,  #= valid file extensions
    #`( --> ?? what’s the type for coroutines again )
) {
    my \requests = paths.map({ $.base.IO.add(.IO) });
    files-from-absolute-paths(requests, exts);
}

=head2 Mod structure matching

#| Split a path on path delimiters, into L<Str> fragments.
our sub path-components(IO:D \path --> List:D)
{
    # this appears to race during multiprocessing and leads to all kinds of headaches
    # path.SPEC.splitdir(path)
    path.path.split(path.SPEC.dir-sep).List
}

#| Work out backwards whether a path fits a pattern. Example:
#| C<path-matches("path/to/a/b/c.txt".IO, <a b c.txt>)>
our sub path-matches(IO:D \path, Positional:D \components --> Bool:D)
{
    my \path-comps = path-components(path);

    components.elems <= path-comps.elems &&
        # from most to least specific component part
        [&&] path-comps.reverse Zeq components.reverse
}

#| Computes the L<Structured> grammars that accept a given file.
our sub candidates(
    IO:D \file,
    Positional:D \grammars,
    --> List:D
) {
    my \dir = file.SPEC.catdir(path-components(file)[^(*-1)]).IO;
    grammars.grep({
        path-matches(dir, .where.List) && .what.ACCEPTS(file.basename)
    }).List;
}

#| Computes topological ordering of files together with their respective structured grammar.
our sub structure(
    Positional:D \files,
    #`(PDS::Structured) @grammars,
    Styles:D :$styles = Styles.new,
    PDS::Grammar :$fallback-grammar = PDS::Unstructured,
    --> List:D
) {
    #| Narrow down to one candidate, and pair with file.
    sub candidate(IO:D \file --> Pair:D) {
        my \shortlist = candidates(file, @grammars);

        if shortlist.elems > 1 {
            note $styles.format-warning(qq:to«END».chomp)
            File {$styles.quote-path(file.path)} is ambiguous because its path matches the following:
            • {shortlist.map({ "{$styles.quote-path(.where.join("/"))} for {.descr}" }).join("\n• ")}
            It is being treated as if it were part of the {shortlist[0].descr}.
            Possible fix: point $styles.attention($*PROGRAM-NAME) to a higher base path to help disambiguate.
            END
        }

        (file) => shortlist ?? shortlist[0] !! $fallback-grammar;
    }

    files.map(&candidate).classify({ .value.?topo-level // Inf }).sort(*.key).map(*.value).List
}
