{ ISO 7185 §6.6.5.4's error condition, which the clause states by construction
  rather than in words: the equivalence assigns `aa[k]` for k running from i,
  and a subscript outside its bounds is an error like any other (§6.5.3.2).

  So the run has to fit. Here the packed array holds five components and the
  index is 7, which would reach a[11] in an array bounded at 10 — and the check
  is made *before* anything is copied, so the destination is untouched when the
  program stops. A partial copy followed by a trap would be worse than none. }
program trap_pack(output);
type unpacked = array [1..10] of char;
     small    = packed array [1..5] of char;
var a: unpacked; z: small; i: integer;
begin
  for i := 1 to 10 do a[i] := 'x';
  z := 'ABCDE';
  writeln('before');
  pack(a, 7, z);
  writeln('not reached')
end.
