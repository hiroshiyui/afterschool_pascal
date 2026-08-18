{ ADR-0121's directive, as the tree records it. `external` is not a reserved
  word and the foreign name is not an identifier, so the only place either
  survives is this node -- which makes the dump the one reader that can show a
  declaration was foreign at all.

  --dump-ast runs before Sema, so what is below is what the *parser* decided:
  a heading, and in the position 6.1.4 gives to `forward`, the name of
  something translated somewhere else. }
program foreign(output);
function cbrt(x: real): real; external 'cbrt';
procedure srandom(seed: integer); external 'srandom';
function twice(x: real): real;
begin
  twice := cbrt(x) + cbrt(x)
end;
begin
  srandom(1);
  writeln(twice(27.0):0:1)
end.
