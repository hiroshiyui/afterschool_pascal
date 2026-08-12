{ ISO 7185 §6.6.5.4's transfer procedures.

  The clause does not describe an operation; it gives a statement sequence each
  is *equivalent to*:

    pack(a, i, z)    k := i; for j := u to v do
                       begin zz[j] := aa[k]; if j <> v then k := succ(k) end
    unpack(z, a, i)  the same, with the assignment the other way round

  where u and v are the smallest and largest values of the packed array's
  index-type. So `i` says where in the *unpacked* array the run of components
  starts, and the packed array's own bounds say how many there are — which is
  why `i` is checked against a's index-type and never against z's.

  The `if j <> v` is the same care the for-statement takes with its own control
  variable: the step is not made after the last iteration, so `succ` is never
  applied at the end of the index type. Nothing here can observe that, and it
  is the reason the equivalence is written that way rather than with a bare
  `k := succ(k)`.

  The two procedures also differ in argument *order* — `pack(a, i, z)` against
  `unpack(z, a, i)` — which is a thing to get wrong once and never again. }
program transfer(output);
type
  unpacked = array [1..10] of char;
  small    = packed array [1..5] of char;
  whole    = packed array [1..10] of char;
  numbers  = array [1..6] of integer;
  triple   = packed array [1..3] of integer;
  { The index-type is any ordinal type, and need not start at one — the
    equivalence is in terms of u, v and i, not of positions. }
  letters  = array ['a'..'j'] of char;
  pair     = packed array [1..2] of char;
var
  a: unpacked;
  z: small;
  w: whole;
  n: numbers;
  t: triple;
  L: letters;
  p: pair;
  i: integer;
  c: char;

procedure showUnpacked(v: unpacked);
var k: integer;
begin
  for k := 1 to 10 do write(v[k]);
  writeln
end;

begin
  for i := 1 to 10 do a[i] := chr(ord('a') + i - 1);

  { A run out of the middle. z gets a[3], a[4], ... a[7]. }
  pack(a, 3, z);
  writeln('pack from 3: ', z);

  { The first and last runs that fit, which are where an off-by-one lives. }
  pack(a, 1, z);
  writeln('pack from 1: ', z);
  pack(a, 6, z);
  writeln('pack from 6: ', z);

  { The whole array, where the two lengths are equal and the only legal
    index is the first. }
  pack(a, 1, w);
  writeln('pack whole:  ', w);

  { unpack writes back into a, so the effect is visible in what a holds
    rather than in what is returned. }
  z := 'VWXYZ';
  unpack(z, a, 6);
  write('unpack at 6: ');
  showUnpacked(a);
  z := '12345';
  unpack(z, a, 1);
  write('unpack at 1: ');
  showUnpacked(a);

  { The component type is anything, not just char. It has to be the *same*
    type in both arrays (ADR-0017's identity), which is what
    transfer_errors.pas pins. }
  for i := 1 to 6 do n[i] := i * 11;
  pack(n, 2, t);
  writeln('integers: ', t[1]:1, ' ', t[2]:1, ' ', t[3]:1);
  t[1] := -1; t[2] := -2; t[3] := -3;
  unpack(t, n, 4);
  write('after unpack:');
  for i := 1 to 6 do write(' ', n[i]:1);
  writeln;

  { An index-type that does not start at one. `i` is a value of *that* type,
    so the run starting at 'c' is L['c'], L['d']. }
  for c := 'a' to 'j' do L[c] := chr(ord('A') + ord(c) - ord('a'));
  pack(L, 'c', p);
  writeln('from a char index: ', p);
  p := 'zz';
  unpack(p, L, 'i');
  writeln('unpacked there: ', L['h'], L['i'], L['j'])
end.
