{ `--format --range=L:H` prints those lines alone, with the layout they have
  in the whole file (ADR-0284).

  The claim worth pinning is the indentation. `doc/roadmap.md` had this down
  as needing "the printer told where its indent begins -- a question about the
  enclosing structure that only a parse can answer", and it does not: the
  printer accumulates that depth itself as it walks the token stream, so the
  lines before the range are walked with the sink closed and the depth on
  arrival is the depth the whole-file format would have.

  The range asked for below starts *inside* the body of a procedure nested
  inside another, so two separate counters have to have survived the walk: the
  routine nesting and the block nesting. Starting it at the declaration part
  instead was the first version of this case, and a mutation that discarded
  the block depth alone passed it -- the depth there is zero either way. }
program formatrange(output);

procedure Outer;
  procedure Inner;
  var k : integer ;
  begin
  k := 1 ;
  if k = 1 then
  writeln( 'inner' ) ;
  end ;
begin
  Inner
end;

begin
  Outer
end.
