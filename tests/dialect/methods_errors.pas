{ **What an implementation and a method-designator cannot be** (AP 6.7.10,
  AP 6.7.10.4, ADR-0410).

  Each line below is one of the ways the construct is written wrongly, and
  several of them are ways a reader *will* write it -- the two implementation
  forms differ by one word-symbol, and the receiver's name is a trap the trait
  form has had since ADR-0340. }
program methods_errors(output);

const Marker = 1;

type
  Point = record x, y: integer end;
  { a field whose spelling a method would want }
  Named = record Len: integer end;
  small = 1..9;
  { a production of 6.4.7's `string` schema, for the refusal below }
  Tag = string(16);

trait Shows;
  procedure Show(protected var p: Self);
end;

{ a field and a routine of one spelling: `n.Len` would name two things, and
  which it named would depend on which was written first }
impl Named;
  function Len(protected var self: Named): integer;
  begin Len := self.Len end;
end;

{ the receiver may not be called `self` where `Self` is written as its type:
  §6.1.2 folds case, so the two are one identifier and the parameter would
  redeclare a name its own type-denoter has already used }
impl Point;
  procedure Move(var self: Self; dx: integer);
  begin self.x := self.x + dx end;
  { a method whose receiver is a `var` parameter, so that chaining onto what
    it returns can be refused below }
  function Grown(protected var self: Point) = r: Point;
  begin r.x := self.x + 1; r.y := self.y + 1 end;
  { an inherent routine writes its own heading: no trait gave this one, so
    there is nothing for the name alone to adopt. Written in *this* block
    rather than one of its own, because a second `impl Point` is refused
    before its routines are read and would mask this. }
  procedure Bare;
  begin end;
end;

{ a second inherent implementation of one type }
impl Point;
  procedure Twice(var self: Point);
  begin self.x := 0 end;
end;

{ a trait where a type belongs -- the `for` left out, which is the likeliest
  way to write this wrongly now that both forms parse }
impl Shows;
  procedure Show;
  begin end;
end;

{ and a name that is neither a type nor a trait: the trailing arm of that
  chain, which is the correct and complete thing to say about a constant, a
  variable, a procedure or an interface standing where a type belongs }
impl Marker;
  procedure Nothing(var self: integer);
  begin end;
end;

{ a subrange takes its host's implementation and can carry none of its own }
impl small;
  procedure Zero(var self: small);
  begin self := 1 end;
end;

{ and neither can a type produced from a schema (AP 6.7.10, ADR-0413): 6.4.7
  interns a production by its schema and its tuple, so `Tag` *is* every other
  `string(16)` in the program and in every component of it. An implementation
  here would be one for all of them, claimed by whoever wrote it first, and
  no component owns a production to claim it with. }
impl Tag;
  function Twice(s: Tag): integer;
  begin Twice := 2 * length(s) end;
end;

var p: Point; n: Named; k: integer; arr: array [1..2] of Point;


begin
  { a name no implementation of the type supplies }
  k := p.Missing;
  p.Missing(1);
  { the same two, where the receiver is **not** a bare name: a bare one is
    6.11.3's qualified form and these are the designator the parser finishes
    on its own, which is a second place the name has to be looked for
    (ADR-0410, ADR-0412) }
  k := arr[1].Missing(1);
  arr[1].Missing;
  { a method-designator on something with no implementations at all }
  k := k.Len;
  { the receiver named where the routine belongs to another type }
  k := n.Doubled;
  { **chaining onto a method result, where the next receiver is a `var`
    parameter.** §6.6.3.3 wants a variable-access for a variable parameter
    and a function-access is not one -- so this is the language's own rule
    and not one this construct invented. A receiver taken *by value* chains,
    which methods.pas does. }
  p.Grown.Move(1)
end.
