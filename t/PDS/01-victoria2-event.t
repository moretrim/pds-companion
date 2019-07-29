=begin COPYRIGHT
Copyright © 2019 moretrim.

This file is part of the test suite for PFH-Tools.

To the extent possible under law, the author has waived all copyright
and related or neighboring rights to this file. This work is published
from France.

A copy of of the CC0 1.0 Universal license is also provided. If not,
see L<https://creativecommons.org/publicdomain/zero/1.0/>.
=end COPYRIGHT

use Test;
use lib 'lib';

use PDS;
use PDS::Victoria2;

=head1 Test file template

my \pds-script = q:to«END»;
country_event = {
    id = 18
    title = "EVTNAME00018"
    desc = "EVTDESC00018"
    picture = "ships"
    major = no

    is_triggered_only = yes

    option = {
        name = "do the thing"
    }
}
END

my \expectations = [
    country_event => [
        id => 18,
        title => '"EVTNAME00018"',
        desc => '"EVTDESC00018"',
        picture => '"ships"',
        :!major,
        :is_triggered_only,
        option => [ name => '"do the thing"' ],
    ]
];

is-deeply soup(PDS::Victoria2::Events, pds-script), expectations, "can we parse a contry event";

# use lib 't/resources';
# use resource-mod;

# is-deeply soup(PDS::Grammar, resource-mod::resource), expectations;

done-testing;
