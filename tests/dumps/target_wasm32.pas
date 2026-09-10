{ ADR-0383: what the layout rules answer for a target that is ILP32 and does
  **not** align an eight-byte datum to four.

  `tests/dumps/target_i386.pas` is this case's twin and the pair is the
  point. i386 was the only 32-bit target here, so one number -- `WordAlign` --
  answered two questions that happened to have the same answer: what a pointer
  aligns to, and what an i64 or a double aligns to. wasm32 is ILP32 with
  `i64:64`, so the answers are 4 and 8, and admitting it split `WideAlign`
  out of `WordAlign`.

  Read the two goldens side by side and that is the whole of the difference:
  `wptr` and `wpair` are identical, `wi64` and `wreal` are 16 bytes here and
  12 there, and `wfile` moves with them, a file being an array of i64. If
  `WideAlign` were folded back into `WordAlign` this golden would change and
  `target-layout` would report the compiler disagreeing with clang -- one
  claim caught in two places, which is what a dump case is for beside a gate.

  A `--dump-layout` case rather than a program: what is pinned is what the
  *compiler* computed, and this suite cannot run a wasm binary -- the runtime
  does not build for the target yet (ADR-0382). }
program target_wasm32(output);

type
  { the two whose alignment differs from i386's }
  wi64    = record c: char; v: int64 end;
  wreal   = record c: char; v: real end;
  { ...and a file, which is an array of i64 and moves with them }
  wfile   = record c: char; v: text end;
  { the two that follow the *pointer* and so agree with i386 }
  wptr    = record c: char; v: ^integer end;
  wpair   = record a: ^integer; b: ^integer end;
  { the two that are the same on every admitted target }
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
