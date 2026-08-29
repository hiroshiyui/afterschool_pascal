{ A component `tests/dumps/uses_module.pas` imports, so that case's `use` lines
  have a defining-point in a file that is not the one being compiled. Nothing
  here is a case of its own: this directory is outside the corpus's glob, for
  the reason tests/extended/components/ is. }
module usebase;

export shared = (kept, Keep);

var
  kept: integer;
procedure Keep(n: integer);
end;

procedure Keep;
begin
  kept := kept + n
end;

to begin do
  kept := 0;

end.
