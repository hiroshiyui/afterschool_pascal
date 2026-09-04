{ AP 6.4.14.6 as ADR-0323 amended it: what a generic body's `take` still
  refuses. Sema accumulates, so one file.

  The amendment admits `take` of a variable whose type is not affine, inside a
  generic body and nowhere else, and leaves everything else about the operation
  where it was. Three things it did not move are here, and each is refused at
  the line of the *generic*, with the activation that asked for the
  instantiation named after it (AP 6.7.3.10.2). }
program generic_owned_errors(output);
type
  List = owned ^Node;
  Node = record key: integer; next: List end;

{ 1. A file is affine and has no move, and being inside a generic changes
     neither. `not IsAffine` is what the amendment asks and not `not IsOwned`,
     which is ADR-0181's split read once more: the file is the member of the
     first set that is in neither of the other two. }
procedure MoveIt(T: type; var a, b: T);
begin
  a := take(b)
end;

{ 2. The position rule is untouched. What `take` emptied has to land in a
     variable, and inside a generic it may have emptied nothing -- but the
     body cannot know that either, so the rule is the same rule. }
function Peek(T: type; var a: T): boolean;
begin
  Peek := take(a) = take(a)
end;

{ 3. And 6.9.4 a): emptying is the threat, so a protected parameter refuses
     the move at an owned instantiation. At any other type the same line is a
     read and is admitted -- which is `Copies` below, and the one place in
     this language where a source line's legality is a fact about the
     activation rather than about the line. }
procedure Bump(T: type; protected var a: T);
var keep: T;
begin
  keep := take(a)
end;

var f, g: text; l, m: List; i, j: integer;
begin
  MoveIt(f, g);
  writeln(Peek(i));
  Bump(i);
  Bump(l);
  writeln(m = nil, ' ', j:1)
end.
