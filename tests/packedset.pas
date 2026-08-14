{ `packed set`, and the rule about it §6.4.5 c) states.

  §6.4.3 makes a set-type a structured-type and §6.4.3.1 lets `packed` precede
  any structured-type, so `packed set of T` is an ordinary ISO 7185 program.
  Nothing in the corpus had ever written one — the word `packed` appears only
  before `array` and `record` — so the whole of this was uncompiled until the
  file was added.

  §6.4.3.1 leaves what `packed` *means* to the implementation, and here it
  means nothing at all: a set is one 256-bit word with a bit per member
  (ADR-0028), so the representation is already as packed as it can be and the
  word is accepted and ignored. It still decides *compatibility*, which is a
  type question and not a representation one — §6.4.5 c) requires two set-types
  to agree on packing, and tests/packedset_compat.pas is the half that shows
  two that do not.

  What keeps that rule from reaching this file is §6.7.1: a set-constructor
  with members "shall denote either a value of the
  unpacked-canonical-set-of-T-type or, if the context so requires, the
  packed-canonical-set-of-T-type". A constructor has therefore not chosen a
  packing and fits either destination, which is why every assignment below is
  legal. This file asserted the opposite until ADR-0093 — that the standard
  does not say what packing `[1]` has — and it is the sentence above that
  says it does. }
program packedset(output);

type
  digit  = 0..9;
  pset   = packed set of digit;

var
  p: pset;
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

  { §6.7.1 again: `[]` is "the value in every set-type that contains no
    members", so it needs no packing of its own either. }
  p := [];
  writeln('empty   ', ord(1 in p):1)
end.
