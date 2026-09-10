{ ADR-0386: what the layout rules answer for wasm64.

  `target_wasm32.pas` is this case's twin one width up, and the pair says the
  whole of what the seventh target cost: nothing. wasm64 is LP64 -- a pointer
  of eight bytes, a C `long` of eight, an eight-byte datum aligned to eight --
  so every arm `PtrSize`, `WordAlign`, `WideAlign` and `CLongSize` already had
  answers it, and `target-layout` puts it in a class with x86-64, aarch64 and
  both Darwin triples and compares all 11 162 frame offsets against theirs.

  Read the three goldens together and the dialect's whole ILP32/LP64 story is
  there: `wi64` is 16 bytes here and on wasm32 and 12 on i386, `wptr` is 16
  here and 8 on both 32-bit targets, and nothing else moves.

  A `--dump-layout` case rather than a program: what is pinned is what the
  *compiler* computed, and there is nothing to run this on -- wasm64 is the
  memory64 proposal and Debian ships no sysroot for it, which is why every
  gate that needs one abstains and says so. }
program target_wasm64(output);

type
  { the five that follow a word or a datum, all eight here }
  wptr    = record c: char; v: ^integer end;
  wi64    = record c: char; v: int64 end;
  wreal   = record c: char; v: real end;
  wfile   = record c: char; v: text end;
  wpair   = record a: ^integer; b: ^integer end;
  { and the two that are the same on every admitted target }
  wset    = record c: char; v: set of char end;
  wcplx   = record c: char; v: complex end;
  { one of everything, to show a whole record's arithmetic }
  wmixed  = record
    a: char; b: ^integer; c: integer; d: real; e: int64; f: char
  end;

var m: wmixed;

begin
  m.a := 'x';
  writeln(m.a)
end.
