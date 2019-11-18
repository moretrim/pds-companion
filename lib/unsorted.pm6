#| Turn a Slip into its singular or Array contents.
our sub unslip($_) is export
{
    when Slip {
        if .elems == 1 {
            .[0]
        } else {
            .Array;
        }
    }
    default {
        $_
    }
}

#| Unslip associative values.
our sub unslip-values(%assoc) is export
{
    %assoc.map({ .key => unslip(.value) }).Hash
}

class GLOBAL::X::IncompatibleMerge is Exception {
    has $.left;
    has $.right;
    has Str @.extra-info is rw = [];

    method message() {
        my Str $suffix = $.extra-info ?? " ({$.extra-info.join(", ")})" !! "";
        "does not know how to merge ‘{$.left.gist}’ [{$.left.^name}], ‘{$.right.gist}’ [{$.right.^name}]$suffix";
    }

    method append-extra-info(+@args) {
        self.extra-info.append(@args);
    }
}

sub merge-items(\left, \right)
{
    # left bias
    if left ~~ Slip {
        return unslip(left)
    }
    if right ~~ Slip {
        return unslip(right)
    }
    given left, right {
        when Associative, Associative {
            merge-associatives(left, right)
        }
        when Positional, Positional {
            Array(|left, |right)
        }
        when Str, Str {
            left ~ right
        }
        default {
            die X::IncompatibleMerge.new(:left(left), :right(right))
        }
    }
}

our proto merge-associatives(|) is export { * }

multi merge-associatives()
{
    Hash.new
}

multi merge-associatives(%only)
{
    %only
}

multi merge-associatives(%left, %right)
{
    my %merged = %left.deepmap(-> $pair is copy { $pair<> });
    for %right.kv -> \key, \value {
        given %left{key} {
            %merged{key} = $_.defined ?? merge-items($_, value) !! unslip(value)
        }
    }
    %merged
}

#| Non-mutating hash 'assignment'.
our sub extend-associative(%target, *%pairs) is export
{
    unslip-values(merge-associatives(%target, %pairs))
}

#| Transitively gather & group all values associated with each key in @keys.
our sub children(\tree, **@keys, :@except = ()) is export
{
    my @pending = [tree];
    [[&merge-associatives]] gather while @pending {
        given @pending.shift {
            when Match {
                @pending.push($_) for .caps;
            }
            when Positional {
                @pending.push(gather .deepmap({ .take }));
            }
            when Associative {
                for .kv -> \key, \val {
                    if key ∈ @keys {
                        ((key) => (val,)).take;
                    } elsif key ∈ @except {
                        next;
                    } else {
                        if val ~~ Positional {
                            @pending.push(key => $_) for val<>;
                        } else {
                            @pending.push(key => val);
                        }
                    }
                }
            }
        }
    }
}
