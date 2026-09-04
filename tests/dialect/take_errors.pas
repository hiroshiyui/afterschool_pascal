{ AP 6.4.14.6: what `take` refuses. Sema accumulates, so one file.

  The position rule is 6.4.12.2's, and it is the whole of what keeps a move
  from being a leak: anywhere but the right side of an assignment to a
  variable of the type, what `take` emptied would be held by no one
  (ADR-0182). }
program take_errors(output);
type
  List = owned ^Node;
  Node = record key: integer; next: List end;
  Other = owned ^Node;
  Plain = ^Node;
var l, m: List; o: Other; z: Plain; k: integer;
procedure Lend(var n: List);
begin end;
type Stream = handle external 'fclose';
function ExtStream(path, mode: string): Stream; external 'fopen';
{ 6.9.4 a): emptying a variable threatens it, so `take` asks Threatened as
  every other threat does.

  This comment used to read that an owned pointer is not a protectable type,
  so the arm below was reachable only in a program already refused for another
  reason -- and that the guard stays anyway, because dropping a check because
  today's type rules make it unreachable is how a permission comes to leak
  later (ADR-0146). AP 6.4.14.8 (ADR-0318) made the type protectable and the
  arm is now the ordinary way this is reported: one error here, not two. The
  argument for keeping it was written before there was anything to keep it
  for, and this is what it bought. }
procedure Protect(protected var n: List);
begin
  m := take(n)
end;
begin
  new(l);
  { the argument is a variable of an owned pointer type, and nothing else }
  m := take(k);
  m := take(z);
  m := take(l^.key);
  { and a variable, not a value -- the second is the one that reaches the
    designator arm, an external's function-designator being the only
    owned-or-handle value that is not one, and it is also what pins that a
    refused argument reports **once**: CheckCall checks every builtin's
    arguments before this dispatch, so CheckTake asking again reported the
    same mistake twice (ADR-0206) }
  m := take(nil);
  m := take(ExtStream('x', 'r'));
  { one argument }
  m := take(l, m);
  { the position: every one of these would empty l and hold what it emptied
    nowhere }
  if take(l) = nil then writeln('empty');
  Lend(take(l));
  writeln(take(l) = nil);
  { the type: 6.4.14.5 makes two written denoters two types }
  o := take(l);
  { and a plain pointer cannot receive one either }
  z := take(l)
end.
