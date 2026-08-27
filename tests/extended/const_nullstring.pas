{ ADR-0220: a name bound to the null-string.

  §6.1.9 spells a character-string with *zero or more* string-elements, so `''`
  denotes the null-string §6.4.3.3.1 names, and §6.3 lets a constant-definition
  name any string constant (ADR-0068). Both halves worked; the two together did
  not.

  A literal is emitted as its characters, and a string *value* is a pointer and
  a length (ADR-0051). The null-string is the one literal whose type is the
  canonical string-type rather than a fixed-string-type -- §6.4.3.3.2 gives no
  fixed-string-type a capacity of zero -- and the canonical one is represented
  as a length word in front of the characters. So the value was read as though
  those four bytes were there. They are not: the global holds the characters
  alone, and for `''` that is nothing at all.

  What it printed was whatever followed in the module's read-only data, for
  however many bytes the first four of them happened to spell. Here that was
  the whole of the runtime's message table.

  The guard for this was already written -- "a literal is its own characters
  and its own length, whatever type it was given" -- and was keyed on the
  node's kind, so it saw `''` and not `e`. A constant reaches the code
  generator as a designator.

  **This case needs -O0 and has a .opt sidecar saying so.** At -O2 the load is
  out of bounds of a one-byte global, LLVM is entitled to fold it, and it folds
  to zero -- which is the right answer by accident. The corpus compiles at -O2,
  which is why nothing here had seen this. It is ADR-0102's shape exactly: a
  defect in *storage* is invisible where the optimiser is free to reason about
  the storage.

  Every path a string value can take is written out, because EmitString is one
  procedure with one arm per shape and the wrong arm was reached from all of
  them. }
program ConstNullString(output);

const empty = '';
      greet = 'hi';

var s: string(10); n: integer; same: boolean;

begin
  { written }
  writeln('write  [', empty, ']');

  { assigned, then written from a variable that holds it }
  s := empty;
  writeln('assign [', s, '] len=', length(s):1);

  { its length as a value, which is the length the reader gets }
  writeln('length ', length(empty):1);

  { concatenated on either side -- §6.8.3.6 makes the result's length the sum }
  s := empty + greet;
  writeln('cat1   [', s, ']');
  s := greet + empty;
  writeln('cat2   [', s, ']');
  s := empty + empty;
  writeln('cat3   [', s, '] len=', length(s):1);

  { compared -- §6.8.3.5 pads the shorter to the longer with spaces }
  same := empty = '';
  writeln('eq     ', same);
  same := empty < greet;
  writeln('lt     ', same);

  { passed, which is the pointer-and-length pair travelling as two words }
  n := index(greet, empty);
  writeln('index  ', n:1)
end.
