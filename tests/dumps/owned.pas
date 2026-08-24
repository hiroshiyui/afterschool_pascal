{ AP 6.4.14 through the dump walkers: the `owned` a denoter carries is part of
  what the parser decided, so --dump-all has to show it or one line stands for
  two types (ADR-0181, and ADR-0176's defect in this same walker). }
program owned(output);
type
  NodePtr = owned ^Node;
  Node = record key: integer; next: NodePtr end;
  Plain = ^Node;
var a: NodePtr; b: Plain;
begin
  new(a);
  a^.key := 1;
  writeln(a^.key, ' ', b = nil)
end.
