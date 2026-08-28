{ ISO/IEC 10206:1991 §6.4.3.3.2 makes a fixed-string-index-type a subrange
  whose first bound "is nonvarying, does not contain a discriminant-identifier,
  and denotes the integer value 1", and requires *nothing* of the largest
  value. ISO 7185 §6.4.3.2 also requires "a largest value of greater than 1",
  so `packed array [1..1] of char` is a fixed-string-type here and is not a
  string-type there.

  That single clause was the only one of §6.4.3.2's four the modes decided, and
  this file is what says so: the other three -- packed, a lower bound of 1, an
  index-type of integer, a component that is char and not a subrange of char --
  bind under both standards, and tests/stringtype_errors.pas is their half.

  Without the gate the capacity-1 fixed string below stops being a string and
  both statements become type errors. }
program StringCapacityOne(output);
var one: packed array [1..1] of char;
begin
  one := 'Z';
  writeln(one);
  writeln(one = 'Z')
end.
