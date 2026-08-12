{ ISO/IEC 10206:1991 §6.7.5.5: "It shall be an error if the equivalent of
  eoln(f) is false upon completion."

  The statement ends with `read(f, ss)`, which takes at most the destination's
  capacity -- so eoln is false exactly when more was written than the string
  can hold. This compiler makes that the capacity check §6.4.6 already puts on
  every string store, which is why the message names the two lengths rather
  than the end of a line nothing in the program can see. }
program TrapWriteStrCapacity(output);
type s4 = string(4);
var s: s4;
begin
  writeln('before');
  writestr(s, 'far too long');
  writeln('unreachable [', s, ']')
end.
