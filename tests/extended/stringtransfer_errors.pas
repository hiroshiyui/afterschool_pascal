{ What ISO/IEC 10206:1991 §6.7.5.5 refuses. Most of these are refused by the
  rules `write` and `read` already had, because a writestr's parameters *are*
  write-parameters and a readstr's variable-accesses are read the way §6.10.1
  reads any -- so the messages are the ones those two statements have always
  produced, and only the first two clauses are this feature's own. }
program StringTransferErrors(output);
type
  colour = (red, green, blue);
  s8 = string(8);
var
  s: s8; f: text; i: integer; c: char; b: boolean; k: colour;

{ §6.9.4 d): writestr threatens the string-variable it writes to, so a
  protected parameter may not be one (§6.7.3.1, ADR-0046). Reading into one is
  the same rule under §6.9.4 c). }
procedure p(protected var guard: s8; protected n: integer);
begin
  writestr(guard, 'x');
  readstr('1', n)
end;

begin
  { "shall possess a fixed-string-type or a variable-string-type" -- a char is
    a string of capacity 1 for §6.4.6's assignment rule but is not a
    string-type, and neither is an integer. }
  writestr(i, 'x');
  writestr(c, 'x');

  { ...and it is a string-*variable*: a literal and an expression have nowhere
    to put the characters. }
  writestr('lit', 'x');
  writestr(s + s, 'x');

  { "The expression of a string-expression shall possess char-type or
    canonical-string-type", so readstr's first parameter may be neither an
    integer nor a file. }
  readstr(i, c);
  readstr(f, c);

  { From here the diagnostics are §6.10's, unchanged: an enumeration has no
    external representation to write or read, a fraction length belongs to a
    real, and a value is not somewhere to read into. }
  writestr(s, k);
  writestr(s, i:1:2);
  readstr('1', b);
  readstr('1', i + 1);
  writeln(s, i:1, c, b, ord(k):1)
end.
