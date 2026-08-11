{ §6.5.3.2: "it shall be an error if the value of the index-expression is not in
  the index-domain of the value of the string-variable". The index-domain is the
  *value's* — 1..length — and not the type's capacity, which is the whole
  difference between indexing a string and indexing an array. }
program TrapStringIndex(output);
var s: string(20);
    i: integer;
begin
  s := 'abc';
  for i := 1 to 3 do write(s[i]);
  writeln;
  { within the capacity and past the length: still outside the index-domain }
  writeln(s[4]);
  writeln('not reached')
end.
