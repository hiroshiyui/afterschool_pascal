{ ISO/IEC 10206:1991 §6.10.1 e) and f) extend `read` to string types, which
  ISO 7185 §6.9.1 does not have: "reading a string does not skip leading
  blanks, never crosses an end-of-line, and takes at most the capacity."

  It is here because nothing else exercised it. The Pascal backend emitted a
  spurious `store` after every string read — C++ says "and now go round again"
  with a `continue`, and the port had no equivalent, so the store fell through
  and wrote whatever register the *previous* argument had left behind. A read
  with one string argument and nothing before it stored an empty operand, which
  is malformed IR; a read of a string *after* an integer stored the integer.
  No program in the corpus did either.

  §6.5.6's substring is a read target too (§6.5.1 makes it a variable-access),
  and its capacity is `hi - lo + 1` rather than its type's — which is the case
  that needs the two to be told apart at all. }
program ReadString(input, output);
type name = string(20);
var f: packed array [1..6] of char; s: name; n: integer; c: char;
begin
  { A fixed-string target is padded with spaces to its capacity. }
  f := '......';
  read(f);
  writeln('fixed  [', f, ']');
  readln;

  { A variable-string target gets exactly what was read. }
  read(s);
  writeln('var    [', s, '] ', length(s):1);
  readln;

  { A string after a scalar — the shape that would store the scalar into the
    string's slot if the two were not told apart. }
  read(n, c, s);
  writeln('mixed  ', n:1, ' [', c, '] [', s, ']');
  readln;

  { A substring: three characters in the middle of a variable, and the
    capacity comes from the bounds rather than from the type. }
  f := '......';
  read(f[2..4]);
  writeln('substr [', f, ']')
end.
