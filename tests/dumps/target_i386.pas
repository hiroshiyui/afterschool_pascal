{ ADR-0325: what the layout rules answer for a target that is not LP64.

  `LlSize` and `LlAlign` were constants until i386 was admitted, and the
  seven arms that wrote 8 are the whole of what moved: a pointer, an i64, a
  double, a file, a handle, and the two-pointer pair a procedural parameter
  and a slice are. This source declares a record of each so that the numbers
  are a golden rather than a claim, and its `.flags` names the target -- which
  is also what makes `TargetIndex`, `PtrSize` and `WordAlign` reachable from
  the corpus at all, no other case compiling for a third target.

  The set and the complex are here for the arms that did **not** move: clang
  aligns an i256 and a `<2 x double>` to 16 on i386 exactly as it does on both
  LP64 targets, which was measured before those two lines were left alone.

  A `--dump-layout` case rather than a program, because what is being pinned
  is what the *compiler* computed and a 32-bit binary is not what this suite
  runs. `target-layout` is the gate that compares these same numbers against
  clang's on every run; this is the half that says they do not move in
  silence. }
program target_i386(output);

type
  { the five whose alignment moved }
  wptr    = record c: char; v: ^integer end;
  wi64    = record c: char; v: int64 end;
  wreal   = record c: char; v: real end;
  wfile   = record c: char; v: text end;
  { and the two-word pair, whose size moved as well }
  wpair   = record a: ^integer; b: ^integer end;
  { the two that did not move }
  wset    = record c: char; v: set of char end;
  wcplx   = record c: char; v: complex end;
  { and one of everything, to show a whole record's arithmetic }
  wmixed  = record
    a: char; b: ^integer; c: integer; d: real; e: int64; f: char
  end;

var m: wmixed;

begin
  m.a := 'x';
  writeln(m.a)
end.
