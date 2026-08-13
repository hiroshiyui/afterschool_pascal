{ §6.6.5.3, D.23: "for dispose, it is an error if the parameter of a
  pointer-type has a nil-value."

  This was checked only for a schema domain (ADR-0043), where stepping back
  over the tuple header turns it into a free of an address that was never
  allocated. For every other domain it was a *harmless* error — freeing nil
  does nothing — and harmless is not the test the standard sets. It is the same
  comparison either way: what differed was the reason to report it, never the
  rule.

  `dispose(p)` also stores nil back into `p` (ADR-0019), so a second `dispose`
  of the same variable reaches this even without a `p := nil` in the source. }
program TrapDisposeNil(output);
type pi = ^integer;
var p: pi;
begin
  new(p);
  p^ := 7;
  writeln('allocated ', p^:1);
  dispose(p);
  writeln('disposed once');
  dispose(p)
end.
