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

unit module PDS::Victoria2;

use PDS;

our grammar Events is PDS::Grammar {
    rule TOP { ^ @<events>=<event>* $ }

    token event { <country-event> }

    rule country-event { 'country-event' '=' <block> }

    rule province-event { <!> }
}
