{ --dump-uses across a program-component (ADR-0246).

  Go-to-definition is only worth having when it crosses a file: the name an
  editor's reader does not already know is exactly the one that was declared
  somewhere else. So the `file` lines at the head of the dump are the table
  the `declfile` field indexes into, and a `1` there sends a caller to the
  component rather than to the document in front of it.

  It also pins what is *not* reported. Everything the component declares and
  uses inside itself is absent: this dump answers about one document, and the
  component's own text is checked with `curFile` naming the component.

  And it is where 6.11.3's **qualified** name is answered. `shared.kept` is
  two applied occurrences and the tree keeps one position for them, so two
  spans are written from that position: the interface's own name, and the
  whole of `shared.kept`. A caller takes the narrowest span containing the
  position it was asked about, which is what makes a point inside `shared`
  find the interface and a point inside `kept` find the variable. The
  interface answers `0` for a line, having no defining-point this compiler
  records -- an interface is registered by its name and not by where it was
  written (ADR-0246). }
program uses_module(output);

import shared qualified;

var
  here: integer;
  { Produces `run` from the component, which re-resolves that schema's body.
    No `use` line comes out of it: the body is another file's text, and this
    dump answers about one document (ADR-0249). }
  path: shared.run(2);

begin
  here := 2;
  shared.Keep(here);
  { A field whose defining-point is in the component: `seen` is declared in
    usebase.pas and selected here, so the answer names file 1 (ADR-0247). A
    field is not a symbol, so this is the second shape of `use` line. }
  shared.marker.seen := here;
  path[1] := here;
  writeln(shared.kept, shared.marker.seen, path[1]:3)
end.
