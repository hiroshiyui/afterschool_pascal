{ ISO/IEC 10206:1991 6.4.3.6: "length(f) shall be less than or equal to
  ord(b) - ord(a) + 1" for a direct-access `file [a..b] of T`. It was in
  doc/implementation-defined.md 3 as an error this processor did not report --
  an eleventh component written to a `file [1..10]` -- and ADR-0050 recorded
  the reason: enforcing it is a check per component written.

  That is what it costs, and no more. The only thing that grows a file's length
  is a write at the end, so the check is made in `put` and nowhere else:
  `update` overwrites in place and cannot reach it, and a seek is already
  refused past the end. Seeking to the append position of a full file stays
  legal right up until something is written there, which is what this program
  does. }
program TrapFileCapacity(output);
var f: file [1..2] of integer;
begin
  rewrite(f);
  f^ := 10; put(f);
  f^ := 20; put(f);
  writeln('two written, which is the whole of it');
  { An update over the last component does not grow the file. }
  SeekUpdate(f, 2); f^ := 99; update(f);
  writeln('and updated in place');
  { The seek is to the append position and is legal; the put is the error. }
  SeekWrite(f, 3);
  f^ := 30; put(f);
  writeln('unreached')
end.
