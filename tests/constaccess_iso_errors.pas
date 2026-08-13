{ A constant may not be selected from in ISO 7185.

  §6.3's constant-definition gives a name to a value; §6.7.1's factor admits a
  `[`, a `.` or a `^` only after a *variable-access*, and a constant-identifier
  is an unsigned-constant. So `squares[2]`, `origin.x` and the rest are not
  sentences of this language. Selecting from a constant is §6.8.8's
  constant-access, which ISO/IEC 10206:1991 adds — `tests/extended/
  constaccess.pas` is that program, and §6.8.8.1's NOTE is what it is for.

  This is refused in Sema rather than in the parser, and it has to be: a
  selector over a name is a designator until the symbol says otherwise, and
  the parser has no scope. "Ask the symbol, not the syntax" (ADR-0072).

  `tests/stringconst.pas` indexed a string constant when it was written, citing
  §6.5.3.2 as though it permitted it — and §6.5.3.2 is about an array-*variable*.
  A wrong citation compiles, runs, prints the right answer and is agreed on by
  both compilers, so no oracle a compiler has can see one. }
program constaccess_iso_errors(output);

const
  squares = 4;
  greet   = 'hello';

var
  i: integer;
  c: char;

begin
  i := 1;

  { A subscript of a string constant — the form this compiler used to accept,
    and the only one ISO 7185 can write with a base that would be legal in the
    next standard. }
  c := greet[i];

  { A field of one. §6.3 admits only a number, a character-string and a
    constant-identifier, so ISO 7185 has no *record* constant to select from —
    but the rule is about the selector and not about the base's type, and a
    `.` after any constant reaches it. So this reports twice: once for
    selecting from a constant at all, and once because an integer has no
    fields either. Deleting the field-selection call site left every one of
    the 246 tests passing until this line existed, the two `.err` files that
    carry the message both getting it from the subscript. }
  i := squares.x;

  { §6.8.8.4's substring is not here and cannot be: it needs a `..` inside a
    subscript, which ISO 7185 has no grammar for. That is a parse error a stage
    earlier and would stop Sema before any message above — so the substring arm
    of the check is unreachable in both standards and is not written.
    `tests/substring_iso.pas` is that half, and
    `tests/extended/constaccess_errors.pas` has all three where all three
    exist. }
  writeln(c, squares:1, i:1)
end.
