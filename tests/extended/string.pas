{ ISO/IEC 10206:1991 §6.4.3.3. "A string-type shall be a fixed-string-type or a
  variable-string-type or the required type designated canonical-string-type."

  §6.4.3.3.3 gives the third of those its schema: "There shall be a schema that
  is denoted by the required schema-identifier `string`. The schema `string`
  shall have one formal discriminant denoted by the required
  discriminant-identifier `capacity`." So `string(n)` is a type produced from a
  required schema, and everything ADR-0039 onwards built for schemata carries
  it — including a schematic formal parameter, whose capacity arrives with the
  actual.

  A string *value* is a pointer and a length, two scalars that travel
  separately (ADR-0051). That is why `substr` and `trim` copy nothing: they are
  a shorter length into the string they came from. }
program Strings(output);
type line = packed array [1..10] of char;

var s: string(12);
    t: string(6);
    fixed: line;
    c: char;
    i: integer;

{ §6.4.3.3.3 through ADR-0040: one body serves every capacity, and `s.capacity`
  reads the tuple the actual brought — the required discriminant is named
  `capacity` and nothing else may name it. }
procedure show(name: char; var v: string);
begin
  writeln(name, ' cap ', v.capacity:2, ' len ', length(v):2, ' [', v, ']')
end;

begin
  { §6.4.6: a value shorter than the capacity is stored at its own length in a
    variable-string, and the length is what `length` answers. }
  s := 'hello';
  show('s', s);

  { §6.8.3.6: "a + b shall denote a value of the canonical-string-type whose
    length shall be equal to the sum of the length of a and the length of b."
    A char joins in, because §6.4.3.3.1 gives it length 1. }
  t := 'ab';
  s := s + ' ' + t;
  show('s', s);
  c := '!';
  s := s + c;
  show('s', s);

  { §6.10.3.6: a string is written at its own length, or right-justified in a
    width. }
  writeln('[', s, ']');
  writeln('[', s:12, ']');

  { §6.4.3.3.2: "The length of all values of a particular fixed-string-type is
    equal to the capacity", so a fixed string is padded on assignment and
    stays that length. §6.4.5 d) makes the two kinds compatible. }
  fixed := 'abc';
  writeln('[', fixed, ']  len ', length(fixed):2);
  s := fixed;
  show('s', s);

  { §6.7.6.7's four enquiries. `trim` takes trailing spaces off — an all-blank
    string yields the null-string — and `substr` is j characters from position
    i, with the two-argument form running to the end. }
  writeln('[', trim(fixed), ']');
  writeln('[', trim('     '), ']');
  writeln('[', substr('abcdefgh', 3, 4), ']');
  writeln('[', substr('abcdefgh', 6), ']');
  { j = 0 is legal and yields the null-string, where a substring-variable may
    not be empty }
  writeln('[', substr('abcdefgh', 3, 0), ']');
  writeln(index('hello world', 'o w'):1, index('hello', 'z'):1,
          index('hello', ''):1, index('', 'a'):1);

  { §6.8.3.5: the operators pad the shorter operand with spaces, which is the
    ISO 7185 divergence that matters — there the lengths had to be equal. }
  writeln('ab' = 'ab  ', ' ', 'ab' < 'abc', ' ', 'b' > 'ab', ' ',
          'ab' <= 'ab');

  { §6.7.6.7's six functions are *not* those operators. NOTE 3 says so
    outright: "LT(a,b) could be false and a<b true". They compare lengths as
    well as characters, so a proper prefix is strictly less than its
    extension where `=` would call the two equal. }
  writeln(eq('ab', 'ab  '), ' ', 'ab' = 'ab  ');
  writeln(lt('ab', 'ab  '), ' ', 'ab' < 'ab  ');
  writeln(ne('ab', 'ab'), gt('b', 'ab'), le('ab', 'ab'), ge('ab', 'a'));

  { §6.4.3.3.3 NOTE 1: "The individual components of a variable-string-type can
    be obtained by indexing it as an array." The bound is the *length* and not
    the capacity — the index-domain belongs to the value. }
  s := 'hello';
  for i := 1 to length(s) do write(s[i], '-');
  writeln;
  s[1] := 'H';
  writeln(s, ' ', s[5]);

  { A schematic formal takes any capacity, and one compiled body serves them
    all. }
  show('s', s);
  show('t', t);

  { The null-string, which §6.4.3.3.1 names: length zero, and legal. }
  s := '';
  show('s', s);
  writeln(length(s):1, ' ', s = '', ' ', s = '   ')
end.
