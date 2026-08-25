{ AP 6.4.12.5: what `release` refuses (ADR-0206). Sema accumulates, so one
  file.

  There is no *position* rule here and that is the difference from `take`,
  whose refusals this otherwise mirrors: what `take` yields is an owned value
  that has to land somewhere, and what this yields is an integer, so a
  function-designator anywhere an integer may be written is safe. What is
  left is the argument -- one of them, a handle, and a variable. }
program release_errors(output);
type
  Stream = handle external 'fclose';
  Owned = owned ^integer;
var s: Stream; k: integer; o: Owned; f: text;

function ExtFopen(path, mode: string): Stream; external 'fopen';

{ 6.9.4 a): emptying a variable threatens it, so `release` asks Threatened as
  every other threat does -- CheckTake's arm, and the same reasoning for
  keeping it. A handle is not a protectable type either, so this arm is
  reachable only in a program already refused for another reason. }
procedure Protect(protected var p: Stream);
begin
  k := release(p)
end;

begin
  { the argument is a variable of a handle-type, and nothing else }
  k := release(k);
  k := release(o);
  k := release(f);
  { a file has a closer of its own and is still not one: 6.4.12 is the type
    whose closer a program named }
  k := release(nil);
  { a variable, not a value -- and the only handle-typed thing that is not a
    designator is an external's function-designator, which 6.4.12.2 admits in
    one position and this is not it }
  k := release(3 + 4);
  k := release(ExtFopen('x', 'r'));
  { one argument }
  k := release(s, s);
  k := release
end.
