{ A module whose types carry routines: an inherent implementation (AP 6.7.10)
  and a trait implementation (AP 6.7), both written in the module-*block*
  where AP 6.7 puts them, and both reachable from the component that imports
  this one (ADR-0411).

  **The export-part names no routine of either.** What a client is given is
  the *type*, and the type carries what is implemented for it -- which is the
  whole of what ADR-0315 wanted from methods: §6.11.2 puts every imported
  name into one scope, and a name that is never in an export-part cannot
  collide with another module's. `Width` below is proof: `PasText` exports one
  and this module implements another, and the two are not the same name. }
module Shapes;

export Shapes = (Circle, Square, CName, Renders, CircleOf, SquareOf,
                 CNameOf);

type
  Circle = record r: integer end;
  Square = record s: integer end;
  { a record a C function may be handed, for the one method shape that keeps
    a foreign linkage name rather than gaining a composed one }
  CName = record bytes: packed array [1..16] of char end;

{ A trait, exported. Its routine names are not in the list above and reach a
  client all the same: they are declared by the trait and the trait is what
  travels. }
trait Renders;
  function Area(protected var me: Self): integer;
  function Scaled(protected var me: Self; by: integer): integer;
end;

function CircleOf(radius: integer): Circle;
function SquareOf(side: integer): Square;
function CNameOf(s: string): CName;

end;

function CircleOf;
var t: Circle;
begin t.r := radius; CircleOf := t end;

function SquareOf;
var t: Square;
begin t.s := side; SquareOf := t end;

function CNameOf;
var t: CName; i: integer;
begin
  for i := 1 to 16 do t.bytes[i] := chr(0);
  for i := 1 to length(s) do
    if i < 16 then t.bytes[i] := s[i];
  CNameOf := t
end;

{ **A foreign method, in a module** (ADR-0411). It is the one implementation
  shape that does *not* take a composed linkage name: ADR-0121's directive
  already gave it one, and what is on the other side of it was translated by
  a C compiler that knows nothing of the type. It crosses a component for
  that reason and not for this record's, which is why it is written here
  beside the ones that cross for the other. }
impl CName;
  function Len(protected var me: CName): csize; external 'strlen';
end;

{ The inherent form. `Width` is a spelling `PasText` also exports; nothing
  here refuses it, because this one is not exported. }
impl Circle;
  { a method with an argument besides the receiver }
  function Grown(protected var me: Circle; by: integer): Circle;
  var t: Circle;
  begin t.r := me.r + by; Grown := t end;

  { a parameterless method: written `c.Width` and so a field selection, which
    is the third of the three shapes a receiver takes (ADR-0410) }
  function Width(protected var me: Circle): integer;
  begin Width := 2 * me.r end;

  { a *procedure*, and one that writes through its receiver }
  procedure Shrink(var me: Circle);
  begin me.r := me.r - 1 end;
end;

{ The trait form, for both types. Two implementations, so the client's table
  has something to choose between. }
impl Renders for Circle;
  function Area;
  begin Area := 3 * me.r * me.r end;
  function Scaled;
  begin Scaled := by * (3 * me.r * me.r) end;
end;

impl Renders for Square;
  function Area;
  begin Area := me.s * me.s end;
  function Scaled;
  begin Scaled := by * me.s * me.s end;
end;

end.
