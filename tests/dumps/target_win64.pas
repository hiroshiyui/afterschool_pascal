{ ADR-0371: what the layout rules answer for a target that is LLP64.

  The three targets before this one were LP64 twice and ILP32 once, so
  `CLongSize` could be, and was, a question about the *pointer* -- four bytes
  where a pointer is four. Win64 is the first target here where the two part
  company: a pointer is eight bytes and a C `long` is four.

  So the numbers below are `target_i386.pas`'s question asked the other way
  round. Every record here lays out **exactly as it does on
  x86_64-pc-linux-gnu**, and that is the finding rather than an omission: the
  datalayout differs from that target's in one field, `m:w` against `m:e`,
  which is the symbol mangling Windows uses and not a size or an alignment.
  A frame holds no C `long`, so the one thing that does differ cannot reach
  these offsets -- which is what makes `target-layout`'s first claim, that
  targets of one word size lay every frame out identically, true of this
  target by construction.

  `clong` is where the difference is, and it is a *foreign* type: AP 6.4.2.7
  gives a binding a way to say "whatever this target's is" so that no
  declaration has to write a number (ADR-0328). The record holding one is
  below, and its size is the whole of what admitting this target changed
  about the compiler's arithmetic.

  Its `.flags` names the target, which is also what makes the Win64 arms of
  `TargetIndex`, `TargetName`, `CLongSize` and the datalayout writer reachable
  from the corpus at all -- `line-coverage` reported twelve statements never
  run when this target was admitted without this case, which is how the file
  came to exist. }
program target_win64(output);

type
  { the same shapes target_i386.pas asks about, at eight-byte alignment }
  wptr    = record c: char; v: ^integer end;
  wi64    = record c: char; v: int64 end;
  wreal   = record c: char; v: real end;
  wfile   = record c: char; v: text end;
  wpair   = record a: ^integer; b: ^integer end;
  wset    = record c: char; v: set of char end;
  wcplx   = record c: char; v: complex end;
  { and the one that is this target's own question: a C `long` beside a
    pointer, which agree on every other target admitted here and do not on
    this one }
  wclong  = record c: char; v: clong end;
  wcsize  = record c: char; v: csize end;
  wmixed  = record
    a: char; b: ^integer; c: integer; d: real; e: int64; f: char
  end;

var m: wmixed;

begin
  m.a := 'x';
  writeln(m.a)
end.
