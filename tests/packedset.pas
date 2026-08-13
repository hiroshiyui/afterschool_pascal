{ `packed set`, and the one rule about it this compiler does not apply.

  §6.4.3 makes a set-type a structured-type and §6.4.3.1 lets `packed` precede
  any structured-type, so `packed set of T` is an ordinary ISO 7185 program.
  Nothing in the corpus had ever written one — the word `packed` appears only
  before `array` and `record` — so the whole of this was uncompiled until now.

  §6.4.3.1 leaves what `packed` *means* to the implementation, and here it
  means nothing at all: a set is one 256-bit word with a bit per member
  (ADR-0028), so the representation is already as packed as it can be and the
  word is accepted and ignored.

  The rule that is not applied is §6.4.5 c): two set-types are compatible only
  if both are designated packed or neither is. Here only the base types are
  compared, so the last two assignments below are accepted where a conforming
  processor must reject them. That is a stated deviation (ADR-0072,
  `doc/implementation-defined.md` §5), and this program is what holds the
  compiler to it — if the check is ever added, this file has to change
  deliberately rather than a deviation quietly disappearing. }
program packedset(output);

type
  digit  = 0..9;
  pset   = packed set of digit;
  uset   = set of digit;

var
  p: pset;
  u: uset;
  q: packed set of char;
  n: digit;
  count: integer;

begin
  { It is a set like any other: the constructor, the operators and `in` all
    work, and none of them asks about packing. }
  p := [1, 3, 5];
  p := p + [7];
  p := p - [1];
  write('members ');
  for n := 0 to 9 do
    if n in p then
      write(n:1);
  writeln;

  count := 0;
  for n := 0 to 9 do
    if n in p then
      count := count + 1;
  writeln('count   ', count:1);

  { A packed set of char, so the base type is the one whose values fill the
    word. }
  q := ['a'..'e'] - ['c'];
  write('chars   ');
  if 'a' in q then write('a');
  if 'c' in q then write('c');
  if 'e' in q then write('e');
  writeln;

  { §6.4.5 c) says these two types are not compatible. This compiler assigns
    between them in both directions, and the deviation is the whole reason
    these two lines are here. }
  u := p;
  writeln('to unpacked   ', ord(3 in u):1, ord(5 in u):1, ord(7 in u):1);
  p := u + [9];
  writeln('back to packed ', ord(9 in p):1);

  { The empty set and a set-constructor have no packing of their own, which is
    the other half of why the check is not made: the standard does not say what
    packing `[1]` has, so requiring agreement would make this depend on how the
    destination was declared. }
  p := [];
  writeln('empty   ', ord(1 in p):1)
end.
