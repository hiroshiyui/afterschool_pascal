{ AP 6.4.14.8 (ADR-0318): a protected owned pointer may not be released. Each
  of AP 6.4.14.3's release points is refused, and so is handing the borrow to
  something that could reach one. }
program owned_protected_errors(output);

type Own  = owned ^Node;
     Node = record v: integer; next: Own end;
     Box  = record p: Own end;

procedure Sink(var o: Own);
begin dispose(o) end;

{ 6.4.14.3: `dispose` applied to it. }
procedure ByDispose(protected var o: Own);
begin dispose(o) end;

{ 6.4.14.3: `new` applied to it, which releases what it held first. }
procedure ByNew(protected var o: Own);
begin new(o) end;

{ 6.4.14.6: the move empties its argument. }
procedure ByTake(protected var o: Own; var t: Own);
begin t := take(o) end;

{ 6.4.14.3: an assignment to it, which releases what it held. }
procedure ByAssign(protected var o: Own; var s: Own);
begin o := take(s) end;

{ 6.9.4 b): handed to a variable parameter that is not itself protected, which
  is how a release would be reached one activation over. }
procedure ByHandingOn(protected var o: Own);
begin Sink(o) end;

{ 6.9.4 h): the unit is the entire-variable, so a release of a component is a
  release of what contains it. }
procedure ByField(protected var b: Box);
begin dispose(b.p) end;

{ --- and the same four, written one dereference deeper ------------------- }

{ AP 6.4.14.8's second paragraph: the clause is about the chain and not about
  its first node, so each of these is attributed to o. Without that, a borrow
  could release everything it was lent except the node it was handed. }
procedure DeepDispose(protected var o: Own);
begin dispose(o^.next) end;

procedure DeepAssign(protected var o: Own; var s: Own);
begin o^.next := take(s) end;

procedure DeepTake(protected var o: Own; var t: Own);
begin t := take(o^.next) end;

procedure DeepHandOn(protected var o: Own);
begin Sink(o^.next) end;

{ A `with` is where the name stops being written down, so the binding carries
  what it was reached through and these two are the two above again. }
procedure WithDispose(protected var o: Own);
begin with o^ do dispose(next) end;

procedure WithTake(protected var o: Own; var t: Own);
begin with o^ do t := take(next) end;

begin end.
