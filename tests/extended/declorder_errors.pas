{ §6.2.2.9: "the defining-point shall precede all applied occurrences" — so
  honouring the written order of the declaration parts (ADR-0069) tightens as
  well as loosens. A variable whose type is defined *after* it used to compile,
  because Sema resolved every type before any variable; it is now the forward
  reference the standard says it is, and the same goes for a constant naming a
  type or a constant that comes later.

  §6.4.4's pointer domain is the one forward reference the standard grants, and
  it is still granted: `link` names a record defined after it in the same
  type-definition-part. That case is here to show what did *not* change.

  Sema accumulates rather than bailing, so every message below comes from one
  run. }
program declorder_errors(output);

var
  early: late;

const
  toosoon = later;
  sized   = size;

type
  late  = integer;
  ptr   = ^cell;
  cell  = record datum: integer; link: ptr end;

const
  later = 7;
  size  = 3;

var
  p: ptr;

begin
  new(p);
  p^.datum := toosoon;
  writeln(early:1, p^.datum:1, sized:1)
end.
