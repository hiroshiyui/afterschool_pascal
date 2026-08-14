{ ISO 7185 §6.4.5 c): "T1 and T2 are set-types of compatible base-types, and
  either both T1 and T2 are designated packed or neither T1 nor T2 is
  designated packed." ISO/IEC 10206:1991 §6.4.5 c) is that sentence word for
  word, so the rule is in both standards and gated on neither.

  §6.7.2.5 carries the other half: the operands of a relational operator "shall
  be of compatible types, or they shall be of the same
  unpacked-canonical-set-of-T-type or packed-canonical-set-of-T-type" -- so two
  *named* set-types disagreeing on packing are neither.

  What keeps this from making `p := [true]` an error is §6.7.1: a set-
  constructor with members denotes "either a value of the
  unpacked-canonical-set-of-T-type or, if the context so requires, the
  packed-canonical-set-of-T-type", so it has not chosen a packing. That is the
  whole reason the check needed a third state rather than comparing two
  booleans, and the legal half of this file is what pins it -- BSI's CONF147
  is the same program from the other side. tests/packedset.pas is the rest.

  A message naming one of these types has to say `packed`, or it names two
  different types by one spelling and the advice about naming a type cannot
  help (ADR-0074). The anonymous pair at the bottom is what pins that. }
program PackedSetCompat(output);

type
  btype = set of boolean;
  ptype = packed set of false..true;

var
  flag: boolean;
  b: btype;
  p: ptype;
  u: set of boolean;          { anonymous, unpacked }
  q: packed set of boolean;   { anonymous, packed   }

begin
  { §6.7.1: legal, and none of these may be reported. }
  b := [true, false];
  p := [true];
  q := [true, false];
  u := [];
  p := [];
  flag := b >= u;             { two unpacked set-types agree }
  flag := p >= q;             { two packed set-types agree   }
  flag := true in p;          { §6.7.2.4: `in` takes either packing }
  b := b + [true];
  p := p - [false];

  { §6.4.5 c): each of these mixes a packed set-type with an unpacked one. }
  flag := b >= p;
  flag := p = b;
  p := b;
  b := p;
  b := b + p;
  flag := u <= q;
  writeln(flag)
end.
