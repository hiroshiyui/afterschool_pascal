{ **A type's routines cross a program-component** (ADR-0411, AP 6.13).

  ADR-0410 gave a type routines of its own and ADR-0338 gave a trait its
  implementations, and every case either landed with was one component: the
  routines went into the emitted module under a *counter*, which
  AppendProcName's own comment says two translations cannot agree on, and
  they went in as `internal` besides. So a client got a call to a name
  nothing defined -- an assembler error for a function, a link error naming
  a symbol no source spells for a procedure, and, where a module's *second*
  method was called, no declaration at all, the extern list having compared
  two symbols that both had no linkage name and found them the same.

  Nothing here is a new construct. Every spelling below is one `methods.pas`
  or `dyn.pas` already exercises; what is new is that the implementation is
  in `components/shapesmod.pas` and this is a different translation. }
program method_component(output);

import Names; Shapes;

type
  AnyShape = dyn Renders;
  Held = owned ^AnyShape;

{ A trait from one component, implemented here for a type from another. The
  implementation is this component's, so its routine keeps a counter and is
  internal -- which is right, and is why both directions are written down. }
impl Naming for Square;
  function Tag;
  begin Tag := Tagged(me.s) end;
end;

procedure Report(protected var it: AnyShape);
begin
  writeln('  area ', Area(it):1, ' doubled ', Scaled(it, 2):1)
end;

procedure Run;
var
  c: Circle; q: Square; nm: CName;
  bag: array [1..2] of Held;
  oc: owned ^Circle; oq: owned ^Square;
  i: integer;
begin
  c := CircleOf(4);
  q := SquareOf(5);

  { the method-designator, on a type from another component }
  writeln('grown ', c.Grown(3).r:1);
  { ...and the call it is a second spelling for }
  writeln('grown ', Grown(c, 3).r:1);
  { the parameterless form, which is a field selection until Sema decides it }
  writeln('width ', c.Width:1);
  { a method that writes through its receiver }
  c.Shrink;
  writeln('shrunk ', c.r:1, ' width ', c.Width:1);

  { a method whose implementation is `external`: the name it is reached by is
    C's and not this compiler's, so it crosses for a different reason than
    everything above it }
  nm := CNameOf('abcd');
  writeln('cname ', nm.Len:1, ' ', Len(nm):1);

  { a trait implemented *there*, called statically from *here* }
  writeln('areas ', Area(c):1, ' ', Area(q):1);
  { ...and a trait implemented here for a type declared there }
  writeln('tag ', Tag(q):1);

  { the trait object: the table is built in this component and names routines
    the other one defines }
  new(oc); oc^ := CircleOf(2);
  new(oq); oq^ := SquareOf(3);
  bag[1] := take(oc);
  bag[2] := take(oq);
  for i := 1 to 2 do
    Report(bag[i]^)
end;

begin
  Run
end.
