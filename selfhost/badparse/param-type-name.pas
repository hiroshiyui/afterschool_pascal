{ 6.6.3.1: a formal parameter's type is a *type-identifier*, and a denoter
  written out in full is not one. `array [` is no longer the way to reach this
  message -- since ISO 7185 6.6.3.7 that begins a conformant array schema, and
  conf-bound-name.pas is what it says instead. }
program p;
procedure q(a: record x: integer end);
begin end;
begin end.
