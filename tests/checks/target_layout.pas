{ The probe tests/checks/target_layout.py compiles for its own frame types.

  It exists because the compiler's own frames are not enough. Every type this
  file names is one selfhost/compiler.pas has no frame slot of, and the first
  of them is why the file is here at all: a set is an i256, and an i256 in a
  record is the exact shape of ADR-0028's segfault -- 16-aligned by the stated
  datalayout and 8-aligned by LLVM's default. A layout comparison drawn only
  from the compiler would have compared four thousand offsets and never asked
  the question that has actually cost this repository a day.

  Nothing here is run. What is read is the frame type definitions the compiler
  emits for it, so this is a Pascal source rather than a hand-written module,
  for the reason ADR-0144 gives: a copy of what the emitter produces is a copy
  free to drift, and only the emitter's own output cannot. }
program target_layout(output);
type
  cs   = set of char;
  rec  = record a: char; s: cs; b: integer; z: complex;
                p: ^rec; q: string(7); o: ?real; n: int64 end;
  arr  = array [1..3] of rec;
  { AP 6.4.12's handle slot, four words: in a record beside a set, and bare }
  hnd  = handle external 'fclose';
  hrec = record h: hnd; s: cs; k: integer end;
var r: rec; a: arr; s1: cs; c: complex; f: file of rec; t: text;
    st: string(100); op: ?cs; i64v: int64; h1: hnd; hr: hrec;

{ A conformant array schema and a schematic formal, so that the two parameter
  shapes carrying bounds beside an address are frames here too. }
procedure inner(var x: rec; y: cs; var z: array [u..v: integer] of rec);
var loc: rec; lset: cs; lc: complex; lt: text;
begin loc := x; lset := y; lc := c; rewrite(lt) end;

begin writeln('x') end.
