{ --dump-uses over a §6.13 program-component rather than a program, which is
  the only way two of its answers can be seen at all.

  A module's `export` clause declares an **interface**, and §6.11.1 registers
  one in a table beside the scope rather than in it -- so it is not a block
  declaration, `NoteBlockDeclarations` cannot reach it, and it needs a
  reporter of its own (ADR-0251). The line for it is the export-part's
  identifier as an occurrence of itself.

  And a module-heading declares a routine whose body arrives further down, so
  this is where ADR-0250's defining occurrence stops being a no-op: §6.2.2.12
  makes the heading and the completing block the *same* routine, `Declare`
  runs at the heading, and the name written at the implementation resolves
  back to it. That is the navigation an editor calls going from a definition
  to its declaration, and no program can produce the shape -- a program has no
  heading to complete. `forward` is the same shape and is reachable in a
  program; a module is where it is unavoidable.

  Everything else here is an ordinary defining occurrence: the interface's
  constituents are applied occurrences in the export list, and the module's
  own declarations report themselves with their types. }
module usesexport;

export exporting = (counted, mark, Bump);

type
  mark = record
    seen: integer
  end;

var
  counted: integer;
procedure Bump(by: integer);
end;

procedure Bump;
begin
  counted := counted + by
end;

to begin do
  counted := 0;

end.
