{ AP 6.4.14.3's release, at a length that used to end in a signal (ADR-0322).

  The release is recursive because a type may own something of its own type,
  and one frame per node meant an owned chain longer than the stack died with a
  SIGSEGV at the end of its block -- measured at between half a million and a
  million nodes on an 8 MB stack, with `built` printed first, so it was the
  release and not the building. It was the one capacity in this language that
  ended in a signal instead of a diagnostic, which is what ADR-0012 says a
  bounded resource must not do.

  The release now *continues* at a field of the domain whose type is an owned
  pointer to that same domain, instead of recursing into it: the field is
  emptied before the rest of the variable is walked, so the walk finds nil
  there, and the loop goes round at what it took out. A chain therefore costs
  one frame however long it is. A tree still costs a frame per level, which is
  the row this narrows rather than closes.

  Built by a loop and not by recursion, so that what this case measures is the
  release alone. }
program owned_deep(output);

const Deep = 1000000;

type Own  = owned ^Node;
     Node = record v: integer; next: Own end;

procedure Run;
var head, fresh: Own; i: integer;
begin
  { push Deep nodes on the front -- 6.4.14.6 twice per node, and no recursion }
  for i := 1 to Deep do begin
    new(fresh);
    fresh^.v := i;
    fresh^.next := take(head);
    head := take(fresh)
  end;
  writeln('built  ', Deep:1, ', front ', head^.v:1)
  { and the release is what leaving this block does }
end;

begin
  Run;
  writeln('released')
end.
