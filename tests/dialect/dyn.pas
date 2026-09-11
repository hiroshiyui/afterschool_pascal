{ **AP 6.7.11's trait object** (ADR-0409, ADR-0315's increment C2): a
  collection whose elements are of different types, which is the thing this
  language could not express.

  Not for want of a container. `array [1..3] of owned ^T` compiles and
  `Vec(owned ^T, n)` takes an owned pointer as a type actual, so the
  collection half was here already; what was missing is a *type* that stands
  for "something that implements this trait" with the implementation carried
  by the value. Without it the only heterogeneous collection expressible is a
  closed variant record, which names every member type where the collection is
  declared -- so a library can never offer one to a program's own types
  (ADR-0408).

  **Three implementations, and one of them is a scalar.** That is not
  decoration: an implementation's `Self` travels by address when it is a
  record and by value when it is an integer (ADR-0017), and a table can hold
  the routine itself only because 6.7.11.1 b)'s `var` parameter form makes
  both of them `(ptr, ptr)`. A trait whose receiver is a value parameter is
  refused for exactly that reason, in dyn_object_safety.pas.

  **The release is observed and not assumed**, as it is in owned.pas and
  take.pas: behind a trait object the concrete type is not known where the
  release is written, so what runs is the routine the table carries -- and a
  stream inside a node is buffered until fclose, so reading the file back
  afterwards says whether the *concrete* release ran and not merely whether
  the box was freed. }
program dyn(output, scratch);

trait Renders;
  procedure Draw(protected var p: Self);
  function Area(protected var p: Self): integer;
  { a routine with a parameter besides the receiver. `Self` stands in the
    first and nowhere else, which is what makes it reachable through the
    object: every implementation resolved `by` in a scope where nothing
    differed, so the call site can read that half of the signature from any
    one of them. }
  function Scaled(protected var p: Self; by: integer): integer;
end;

type
  { 6.7.11.1 NOTE 3: the name is made here, because 6.4.14 wants a
    type-identifier for the domain and `owned ^dyn Renders` is not a
    spelling. }
  Shape = dyn Renders;
  AnyShape = owned ^Shape;

  Stream = handle external 'fclose';
  Circle = record r: integer end;
  Square = record s: integer end;
  { a concrete type that *owns* something, which is the case the release has
    to walk: disposing the box must reach this handle }
  Logged = record tag: integer; out_: Stream end;

var
  scratch: bindable text; bnd: BindingType; line: string(60);

function ExtFopen(path, mode: string): Stream; external 'fopen';
function ExtFputs(t: string; s: Stream): integer; external 'fputs';

impl Renders for Circle;
  procedure Draw;
  begin writeln('circle of radius ', p.r:1) end;
  function Area;
  begin Area := 3 * p.r * p.r end;
  function Scaled;
  begin Scaled := by * (3 * p.r * p.r) end;
end;

{ **Declared in a different order from the trait's headings, deliberately.**
  A slot is a position in the *trait*, because that order is the only thing
  two concrete types reached through one object have in common -- and if every
  implementation here wrote its routines in the trait's order, a table built
  from the implementation's own order would be identical and this case could
  not tell the two apart. Two of the four are shuffled so that it can. }
impl Renders for Square;
  function Scaled;
  begin Scaled := by * (p.s * p.s) end;
  procedure Draw;
  begin writeln('square of side ', p.s:1) end;
  function Area;
  begin Area := p.s * p.s end;
end;

{ an implementation for a type with no fields at all: the receiver arrives as
  an address here exactly as the two records do, which is what makes one table
  shape serve every implementation }
impl Renders for integer;
  function Area;
  begin Area := p end;
  function Scaled;
  begin Scaled := by * (p) end;
  procedure Draw;
  begin writeln('bare integer ', p:1) end;
end;

impl Renders for Logged;
  procedure Draw;
  begin writeln('logged ', p.tag:1) end;
  function Area;
  begin Area := p.tag end;
  function Scaled;
  begin Scaled := by * (p.tag) end;
end;

{ 6.7.11.1 b): a borrow for the duration of the call, and the only second name
  a trait object has. `protected var` because this reads and does not write --
  and it is a `var` parameter all the same, which is what 6.7.11.1 b) permits
  and what makes the receiver an address. }
procedure Report(protected var d: Shape);
begin
  Draw(d);
  writeln('  area ', Area(d):1)
end;

procedure ReadBack;
begin
  bnd := binding(scratch);
  bnd.name := 'dyn_scratch.tmp';
  bind(scratch, bnd);
  reset(scratch);
  readln(scratch, line);
  writeln('read back: ', line);
  unbind(scratch)
end;

procedure Run;
var
  bag: array [1..4] of AnyShape;
  c: owned ^Circle; s: owned ^Square; n: owned ^integer;
  i, total: integer;
begin
  new(c); c^.r := 2;
  new(s); s^.s := 5;
  new(n); n^ := 7;
  { the coercion: `take` is still what is written, and what the target gains
    beside the address is the implementation }
  bag[1] := take(c);
  bag[2] := take(s);
  bag[3] := take(n);
  total := 0;
  for i := 1 to 3 do begin
    Report(bag[i]^);
    total := total + Area(bag[i]^)
  end;
  writeln('total ', total:1);
  { the second parameter travels as it would to any routine: the table
    decides the code and the link, and nothing else about the call changes }
  writeln('doubled ', Scaled(bag[1]^, 2):1, ' ', Scaled(bag[3]^, 2):1);
  { an empty element is nil and is released by doing nothing }
  writeln('the fourth is empty: ', bag[4] = nil)
end;

{ the release, twice over: an explicit dispose and the end of a block, which
  must be the same release and are -- both go through the routine the table
  carries }
procedure Drop(explicit: boolean);
var d: AnyShape; g: owned ^Logged;
begin
  new(g);
  g^.tag := 1;
  g^.out_ := ExtFopen('dyn_scratch.tmp', 'w');
  if ExtFputs('closed by the release the table carried', g^.out_) >= 0 then
    d := take(g);
  if explicit then dispose(d)
end;

begin
  Run;
  Drop(true);
  ReadBack;
  Drop(false);
  ReadBack
end.
