{ PasToml: what a document may not be, and where it is said.

  TOML's one-definition rule is most of this file, and it is the part of the
  format a parser is likeliest to get wrong in the *lenient* direction: every
  refusal below is of a document some reader somewhere accepts. The rules turn
  on **how** a table came to exist and not on whether it exists -- so a header
  may open a table a deeper header created implicitly and may not open one a
  dotted key created. The second block is the programs that must go on being
  accepted, which is what stops the first block from being satisfied by
  refusing everything.

  The **position** is checked as well as the code. A configuration file is read
  by a person who has to find the line, and `TomlPositionOf` is what turns the
  byte the parser stopped at into one; a refusal naming the wrong line would be
  worse than a wrong code, and no other case here would notice.

  A `|` in a source below stands for a newline, so that each document is one
  Pascal string. }
program lib_toml_errors(output);

import PasError; PasToml;

var at, line, col: integer;


procedure Refuse(what: string; src: string);
var r: TomlResult; b: TomlChars; k: integer;
begin
  TomlCharsNew(b);
  for k := 1 to length(src) do
    if src[k] = '|' then TomlCharsAdd(b, chr(10)) else TomlCharsAdd(b, src[k]);
  r := TomlParseChars(b, at);
  TomlPositionOf(b, at, line, col);
  write(what:26, ': ');
  if r.ok then begin
    writeln('ACCEPTED (should not be)');
    TomlFree(r.val)
  end
  else
    writeln(ErrorText(r.cause), ' at ', line:1, ':', col:1);
  TomlCharsFree(b)
end;

procedure Accept(what: string; src: string);
var r: TomlResult; b: TomlChars; k: integer;
begin
  TomlCharsNew(b);
  for k := 1 to length(src) do
    if src[k] = '|' then TomlCharsAdd(b, chr(10)) else TomlCharsAdd(b, src[k]);
  r := TomlParseChars(b, at);
  write(what:26, ': ');
  if r.ok then begin
    writeln('accepted');
    TomlFree(r.val)
  end
  else begin
    TomlPositionOf(b, at, line, col);
    writeln('REFUSED ', ErrorText(r.cause), ' at ', line:1, ':', col:1)
  end;
  TomlCharsFree(b)
end;

begin
  Refuse('a key defined twice', 'a = 1|a = 2');
  Refuse('a table defined twice', '[a]|[a]');
  Refuse('a header over a dotted key', 'a.b = 1|[a]');
  Refuse('a header inside a dotted key', '[t]|a.b = 1|[t.a]');
  Refuse('an array is not a table array', 'a = [1]|[[a]]');
  Refuse('reaching into an inline table', 'p = { x = 1 }|[p.q]');
  Refuse('a table array over a table', '[a]|[[a]]');
  { The three that reach `Descend` rather than the final segment, which is a
    different arm of the same rule and was reached by nothing until a mutation
    said so: the refusals above all land on the *last* segment of a path, and
    these land on one it passes through. }
  Refuse('a header through a dotted table', 'a.b.c = 1|[a.b.d]');
  Refuse('a dotted key into a header', '[a.b]|[a]|b.c = 2');
  Refuse('extending an inline table', 'p = { x = 1 }|p.y = 2');
  Refuse('a leading zero', 'a = 01');
  Refuse('a trailing underscore', 'a = 1_');
  Refuse('a leading underscore', 'a = _1');
  Refuse('a doubled underscore', 'a = 1__0');
  Refuse('a signed hexadecimal', 'a = -0x10');
  Refuse('an integer out of range', 'a = 9999999999');
  Refuse('the 30th of February', 'a = 1979-02-30');
  Refuse('an hour of 25', 'a = 25:00:00');
  Refuse('an unterminated string', 'a = "no end');
  Refuse('a newline in a string', 'a = "one|two"');
  Refuse('two pairs on one line', 'a = 1 b = 2');
  Refuse('a bare value', 'a = what');
  Refuse('a missing value', 'a =');
  Refuse('a lone surrogate', 'a = "\ud800"');
  Refuse('a point with no fraction', 'a = 1.');
  Refuse('a fraction with no point', 'a = .5');
  Refuse('a newline in an inline table', 'p = { x = 1,|y = 2 }');
  Refuse('a trailing comma inline', 'p = { x = 1, }');
  Refuse('a multi-line string key', '"""a""" = 1');

  writeln;
  Accept('a super-table afterwards', '[a.b]|c = 1|[a]|d = 2');
  Accept('two dotted keys, one table', 'a.b = 1|a.c = 2');
  Accept('a table array then a table', '[[a]]|[a.b]|c = 1');
  Accept('an empty document', '');
  Accept('comments and blank lines', '# one||  # two|a = 1  # three');
  Accept('an empty inline table', 'p = {}');
  Accept('an empty array', 'a = []');
  Accept('a quoted key with a dot', '"a.b" = 1');
  Accept('a bare key of digits', '1234 = 1');
  Accept('maxint', 'a = 2147483647');
  Accept('a space before the time', 'a = 1979-05-27 07:32:00');
  Accept('a date then a comment', 'a = 1979-05-27 # today')
end.
