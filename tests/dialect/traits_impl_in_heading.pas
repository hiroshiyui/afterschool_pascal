{ An implementation-declaration written in a module's interface is refused
  where it is written (ADR-0341): the heading holds headings, and an impl has
  bodies. The program importing it, through an import path, is what makes the component translate at all,
  and it does nothing else. }
program traits_impl_in_heading(output);
import traitheadmod;
var p: Point;
begin
  p.x := 1;
  writeln(p.x:1)
end.
