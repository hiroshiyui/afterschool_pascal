{ ISO 7185 §6.3's string constant.

  The grammar of a constant-definition's right-hand side is

      constant = [ sign ] ( unsigned-number | constant-identifier )
               | character-string .

  so a `character-string` is a constant, and §6.4.3.2 makes one of more than a
  single character a value of a packed array of char. A one-character literal
  is a char and always was; two characters is where a `Symbol`'s scalar fields
  run out, which is why this was missing until ADR-0068.

  A string constant is *its literal, named* — the same characters in the same
  private global — so everything a literal could already do it can do too, and
  the point of this program is that no operation here needed a case for it. }
program stringconst(output);

{ §6.2.1 fixes the order of a block's parts — label, const, type, var, then
  procedures — so the constants come first here. They were written after the
  types when this program was new, which ISO 7185 has no grammar for; nothing
  caught it, because the order was not being checked in either standard
  (ADR-0072). }
const
  hello = 'hello, world';
  { A constant may name another constant (§6.3's constant-identifier), and the
    value carried along is the same node — so `same` and `hello` are one
    literal written once. }
  same  = hello;
  ab    = 'ab';
  { The characters are the value, so an apostrophe doubled in the source is
    one character in the constant (§6.1.7). }
  quote = 'it''s';

type
  pair  = packed array [1..2] of char;
  greet = packed array [1..12] of char;

var
  p: pair;
  g: greet;
  i: integer;

{ §6.6.3.2 makes an actual value parameter an *expression*, and a
  constant-identifier is one — so a string constant may be copied into a value
  parameter although it is not a variable. `var` is the other way round, and
  `stringconst_errors.pas` is where that is pinned. }
procedure show(s: greet);
begin
  writeln(s)
end;

begin
  writeln(hello);
  writeln(same);
  writeln(quote);
  show(hello);

  { Assignment out of a constant, and comparison against one: §6.4.5 makes the
    types identical by length, which is the standard's own exception to name
    equivalence for packed char arrays. }
  g := hello;
  writeln(g);
  p := ab;
  if p = ab then
    writeln('compares equal');
  if p <> 'ba' then
    writeln('and unequal to another literal');

  { A constant may not be *selected from* in this language. §6.5.3.2's
    indexed-variable takes an array-variable, and §6.7.1 admits a `[` only
    after a variable-access — a constant-identifier is an unsigned-constant, so
    `hello[1]` is not a sentence of ISO 7185. Selecting from one is §6.8.8's
    constant-access, which ISO/IEC 10206:1991 adds; the positive program is
    `tests/extended/stringconst_ops.pas` and the refusal is in
    `stringconst_errors.pas`.

    This program indexed `hello` when it was written, with §6.5.3.2 cited as
    though it permitted it. Nothing caught that: the construct compiled, the
    output was right, and both compilers agreed — a wrong citation is invisible
    to every oracle a compiler has (ADR-0072).

    So what is left here is copying the whole constant into a variable, which
    is what ISO 7185 gives a program that wants its characters. }
  g := hello;
  for i := 1 to 12 do
    write(g[i]);
  writeln;
  writeln(ord(g[1]):1, ' ', g[12])
end.
