{ A component `tests/dumps/uses_module.pas` imports, so that case's `use` lines
  have a defining-point in a file that is not the one being compiled. Nothing
  here is a case of its own: this directory is outside the corpus's glob, for
  the reason tests/extended/components/ is. }
module usebase;

export shared = (kept, Keep, mark, marker);

type
  { A record whose fields are declared *here*, so a selection written in the
    importing program has a defining-point in this file (ADR-0247). }
  mark = record
    seen: integer;
    tag: char
  end;

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
