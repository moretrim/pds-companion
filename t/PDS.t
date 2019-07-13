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

use Test;
use lib 'lib';

use PDS;

my \text = q:to«end»;
  # a
hello  # b
  # c
    =  world  # d

# e

"hallo"  # f

# g


= welt
end

my \pairs = %{
    'hello' => 'world',
    '"hallo"' => 'welt',
}

is soup(PDS::Grammar.parse(text)), pairs;

my \events = q:to«end»;
country_event = {
    id = 42
}
end

done-testing;
