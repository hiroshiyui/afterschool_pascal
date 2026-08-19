{ ADR-0125, in the direction that refuses. Sema accumulates, so one file
  carries every refusal that is not a parse error.

  `array of T` is a *parameter form*, which is what most of this is about: the
  denoter is legal directly as a formal parameter's own type and nowhere else,
  and one test says so for a type-definition, a variable, a field and a nested
  position alike. }
program slice_types(output);

type
  colour = (red, green);
  { Not a type, however much it looks like one. }
  reals = array of real;
  holder = record part: array of real end;

var
  loose: array of real;
  q: real;
  ch: char;
  r: array [1..4] of real;
  n: array [1..4] of integer;
  e: array [red..green] of real;

{ A value parameter is a copy, and a copy is not a view. }
procedure byValue(s: array of real);
begin
end;

{ A slice of slices is neither an address nor one length. }
procedure nested(var s: array of array of real);
begin
end;

{ A file has no copy and no value (ADR-0021), so it has no components a slice
  could view. }
procedure files(var s: array of text);
begin
end;

function Total(protected var s: array of real): real;
begin
  Total := length(s)
end;

{ A slice's index-domain is 1..length and no type names it, so the subscript
  is an integer -- the same rule §6.5.3.2 gives a variable-string. }
procedure indexed(var s: array of real; c: char);
begin
  s[c] := 0
end;

begin
  { The component type has to agree; the extent is exactly what does not. }
  writeln(Total(n):0:1);
  { And the actual has to be an array or a slice of one. }
  writeln(Total(q):0:1);
  { An enumerated index has no arithmetic a slice could be built from --
    whether the whole array is passed or a part of it is named. }
  writeln(Total(e):0:1);
  writeln(Total(e[red..green]):0:1);
  { The bounds of a slice are integers even where the base's index type is. }
  writeln(Total(r[ch..ch]):0:1);
  indexed(r, ch);
  writeln(Total(r):0:1)
end.
