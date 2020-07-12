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

#| Game or mod file structure. [Partially implemented]
unit class PDS::Overlay does Styles::Stylish;

#| Game or mod directory basename, under which all mod files live. Given any path that contains this
#| base directory, it can be understood thusly using the following example:
#|
#|     fake-path/to/my-mod/real-path/to/my-mod/common/defines.lua
#|
#| - `fake-path/path/to/my-mod/real-path/to` (whether relative or absolute) is the location prefix,
#|   leading to where the game or mod lives.
#| - the last occurrence of `my-mod` is the actual game or mod directory
#| - `common/defines.lua` is a game or mod path, typically `common` being a directory and thus
#|   defining some part of the mod structure and `defines.lua` being a file in that substructure.
#|   These usually respectively connect to the L<PDS::Structured::where> and
#|   L<PDS::Structured::what> methods of L<PDS::Structured>.
#|
#| Note that those last two points may preclude L<PDS::Overlay> from working correctly for a base
#| name that happens to be the same as a directory or file under the intended mod structure.
has Str:D $.base = $*CWD.basename;

=head2 Computing mod files

#| Compute mod files of interest from directories, files, & valid extensions.
method files-from-paths(
    Positional:D \paths, #= mod paths to turn into file paths
    Positional:D \exts,  #= valid file extensions
    #`( --> ?? what’s the type for coroutines again )
) {
    my @pending = paths.map(*.IO) #`(.grep({ $.base ∈ .&path-components }));
    while @pending {
        with @pending.shift {
            when :d { @pending.append(.dir) }
            .cleanup.take when .extension(:parts(^Inf)).fc ~~ *.ends-with(exts.any);
        }
    }
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
sub candidates(
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
method structure(
    Positional:D \paths, Positional:D \exts,
    #`(PDS::Structured) @grammars,
    PDS::Grammar :$fallback-grammar = PDS::Unstructured,
    --> List:D
) {
    #| Narrow down to one candidate, and pair with file.
    sub candidate(IO:D \file --> Pair:D) {
        my \shortlist = candidates(file, @grammars);

        if shortlist.elems > 1 {
            note $.styles.format-warning(qq:to«END».chomp)
            File {$.styles.quote-path(file.path)} is ambiguous because its path matches the following:
            • {shortlist.map({ "{$.styles.quote-path(.where.join("/"))} for {.descr}" }).join("\n• ")}
            It is being treated as if it were part of the {shortlist[0].descr}.
            Possible fix: point $.styles.attention($*PROGRAM-NAME) to a higher base path to help disambiguate.
            END
        }

        (file) => shortlist ?? shortlist[0] !! $fallback-grammar;
    }

    my @files = gather $.files-from-paths(paths, exts);
    @files.map(&candidate).classify({ .value.?topo-level // Inf }).sort(*.key).map(*.value).List
}
