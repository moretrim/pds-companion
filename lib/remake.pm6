use unsorted;

our sub remake($/, *%pairs) is export
{
    make(extend-associative(($/.made // %{}), |%pairs));
}
