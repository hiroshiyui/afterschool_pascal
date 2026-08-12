{ ISO/IEC 10206:1991 §6.5.6's substring-variable and §6.8.6.5's
  substring-function-access. One notation, `s[i..j]`, and two clauses because
  what the base is decides whether the result is a *variable*:

    §6.5.6   substring-variable       = string-variable `[' e `..' e `]'
    §6.8.6.5 substring-function-access = string-function `[' e `..' e `]'

  This compiler has one node for both, because the difference is exactly
  "is the base a designator" — a question `isDesignator` was already asking.

  Under ADR-0051 a string value is a pointer and a length, so a substring
  copies nothing: it is the base's pointer advanced by `i - 1` and the length
  `j - i + 1`. Reading one is three instructions. §6.5.6 calls the result "a
  new fixed-string-type" whose capacity is `j - i + 1`, and that capacity is
  not a compile-time number — but nothing observable needs it to be one, since
  the only rule that reads it is the store, which reads it at run time from
  the same subtraction.

  Which is the point worth keeping: assigning *to* a substring is the ordinary
  fixed-string store, unchanged. §6.4.6 pads a shorter value with spaces and
  refuses a longer one, and that is already what `pas_str_store_fixed` does. }
program Substring(output);
type
  name  = string(20);
  tag   = packed array [1..8] of char;

var s: name; f: tag; i, j: integer;

function greeting = t: name;
begin t := 'hello world' end;

begin
  s := 'abcdefgh';

  { Reading: a value like any other, so it writes, concatenates and compares. }
  writeln('read   [', s[2..4], ']');
  writeln('one    [', s[3..3], ']');
  writeln('whole  [', s[1..8], ']');
  writeln('cat    [', s[1..2] + s[7..8], ']');
  writeln('len    ', length(s[2..5]):1);

  { Writing. The value's length must fit the capacity `j - i + 1`; a shorter
    one is padded with spaces, which is §6.4.6's fixed-string rule and not
    something this feature invented. }
  s[2..4] := 'XYZ';
  writeln('exact  [', s, ']');
  s[6..8] := 'p';
  writeln('padded [', s, ']');

  { The bounds are expressions, evaluated where they stand. }
  i := 2;
  j := 5;
  s := 'abcdefgh';
  writeln('expr   [', s[i..j], ']');
  writeln('calc   [', s[i + 1..j + 2], ']');

  { A fixed-string-type base — §6.4.3.3.2 gives it a length equal to its
    capacity, so the whole of it is in range. }
  f := 'abcdefgh';
  writeln('fixed  [', f[3..5], ']');
  f[1..2] := 'ZZ';
  writeln('fixed  [', f, ']');

  { §6.8.6.5: the base is a function-access, so the substring is a *value* —
    there is nothing to assign to, and `substring_errors.pas` says so. }
  writeln('func   [', greeting[1..5], ']');
  writeln('func   [', greeting[7..11], ']');

  { §6.8.3.5 pads the shorter operand, so a comparison over substrings is the
    ordinary string comparison. }
  s := 'abcabc';
  if s[1..3] = s[4..6] then writeln('equal') else writeln('differ');
  if s[1..2] < s[2..3] then writeln('less') else writeln('not less')
end.
