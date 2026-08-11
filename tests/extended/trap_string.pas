{ §6.4.6 c): "it shall be an error if T1 and T2 are compatible, T1 is a
  string-type or the char-type, and the length of the value of T2 is greater
  than the capacity of T1." The capacity is the type's and the length is the
  value's, so this is a question only the running program can answer — which is
  why a *shorter* value is fine and only a longer one stops. }
program TrapString(output);
var s: string(5);
    t: string(20);
begin
  s := 'abc';
  writeln('[', s, ']');
  t := 'this is rather long';
  writeln('[', t, ']');
  s := t;
  writeln('not reached')
end.
