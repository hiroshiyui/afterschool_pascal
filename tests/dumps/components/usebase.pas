{ A component `tests/dumps/uses_module.pas` imports, so that case's `use` lines
  have a defining-point in a file that is not the one being compiled. Nothing
  here is a case of its own: this directory is outside the corpus's glob, for
  the reason tests/extended/components/ is. }
module usebase;

export shared = (kept, Keep, mark, marker, run);

type
  { A record whose fields are declared *here*, so a selection written in the
    importing program has a defining-point in this file (ADR-0247). }
  mark = record
    seen: integer;
    tag: char
  end;
  { A schema declared here and produced *there* -- `run(2)` in
    uses_module.pas. 6.4.7 re-resolves this body where the type is written, so
    the occurrence of `size` in it is text of this file being read while the
    compiler is checking that one. Nothing is reported for it, which is the
    whole of ADR-0249's negative half: a production reports only when the
    schema is the document's own. }
  run(size: integer) = array [1..size] of integer;

var
  kept: integer;
  marker: mark;
procedure Keep(n: integer);
end;

procedure Keep;
begin
  kept := kept + n
end;

to begin do
  begin
    kept := 0;
    marker.seen := 0;
    marker.tag := '-'
  end;

end.
