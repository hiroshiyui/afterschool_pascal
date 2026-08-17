{ A concatenation in a loop's *condition*, which is the one expression a
  statement re-evaluates. The release at the end of the statement is no use
  here -- it runs once, after the loop -- so `while` and `repeat` release their
  condition's temporaries where the condition is evaluated (ADR-0111).

  Both bodies are deliberately free of string operations: if the body released
  anything the condition would be reclaimed by accident and this would pass
  with the release missing. }
program strarenacond(output);
var a, b: string(50); i: integer;
begin
  a := 'abcdefghij';
  b := 'abcdefghijabcdefghij';

  i := 0;
  while (a + a = b) and (i < 100000) do
    i := i + 1;
  writeln('while ', i:1);

  i := 0;
  repeat
    i := i + 1
  until (a + a <> b) or (i = 100000);
  writeln('repeat ', i:1)
end.
