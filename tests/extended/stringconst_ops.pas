{ ISO 7185 §6.3's string constant, under the other standard.

  ISO/IEC 10206:1991 §6.3.1 writes the same rule as `constant-expression`, and
  §6.4.3.3 gives a literal of more than one character a fixed-string-type —
  which this compiler spells as the packed array of char it has always been
  (ADR-0051). So the constant's type is the literal's type in either language,
  and there is no `--std` case anywhere in the feature.

  What is new here is what Extended Pascal can *do* with one. Every operation
  below is §6.7.6.7's or §6.8.3.6's, applied to a value that is not a variable.

  §6.11's modules are here for the one path a bare name does not reach: a
  qualified constant-name, which is a different node and a different arm of
  `emitAddress`. }
module strings(output);
  export text = (banner, digits);
  const
    banner = 'afterschool';
    digits = '0123456789';
end;
end.

program stringconst_ops(output);
import text;

var
  s: string(32);
  i: integer;

begin
  { A bare imported name, and the qualified form of the same constant. }
  writeln(banner);
  writeln(text.banner);

  { §6.8.3.6's concatenation, with a constant on either side of it. }
  s := banner + ' pascal';
  writeln(s);
  s := 'the ' + banner;
  writeln(s);

  { §6.7.6.7's substr and length over a constant. `trim` has nothing to take
    off a literal, which is the point — a fixed-string value arrives padded
    only when it comes from a variable. }
  writeln(substr(banner, 1, 5));
  writeln(length(banner):1, ' ', length(digits):1);
  writeln(index(digits, '7'):1);

  { §6.5.6's substring of a constant. The base is not a variable, so this is
    §6.8.6.5's value form — one node, and the base is the whole difference. }
  writeln(digits[3..6]);

  { §6.8.3.5 pads the shorter operand with spaces, so a constant compares
    against a longer value of a different length — which ISO 7185 refuses and
    `stringconst_errors.pas` pins there. }
  if banner < 'afterschools' then
    writeln('padded comparison');
  { §6.7.6.7's EQ/LT family compares the lengths too, and NOTE 3 says the two
    can disagree. Here they do. }
  if not EQ(banner, 'afterschool ') then
    writeln('and lengths compared');

  { A constant is indexable, and a `for` over it needs nothing of its own. }
  for i := 1 to 10 do
    write(digits[11 - i]);
  writeln
end.
