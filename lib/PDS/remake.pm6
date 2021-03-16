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

#| Like L<make>, but preserves the existing C<.made> data through merging or concatenating.
#|
#| Not for public consumption.
unit module PDS::remake;

use PDS::unsorted;

our sub remake($/, *%pairs) is export {
    make(extend-associative(($/.made // Hash.new), |%pairs))
}
