{ What the five refuse. Sema accumulates, so they share a file. }
program RequiredErrors(output);
type digits = set of 0..9; colour = (red, green, blue);
var s: digits; i: integer; c: colour; r: real;
begin
  { §6.7.6.3's `card` takes a set and nothing else. }
  i := card(3);

  { §6.8.3.4's `><` is an adding-operator over sets, where `+` and `-` are
    also arithmetic — so this is the one adding-operator with no numeric
    reading at all. }
  i := 1 >< 2;

  { §6.7.6.4's second argument is how far to step, and must be an integer. }
  c := succ(red, 1.5);

  { ...and there is no third. }
  c := succ(red, 1, 2);

  { §6.4.2.2 d) makes maxchar a *value*, not a variable. }
  { §6.7.5.7's halt takes nothing. }
  halt(1);

  r := 0.0;
  s := [];
  writeln(i:1, r:1:1, card(s):1)
end.
