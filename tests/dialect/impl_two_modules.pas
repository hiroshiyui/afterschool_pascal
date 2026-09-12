{ AP 6.7.10: two modules may not both give one type an implementation of its
  own. Each of `ShapeArea` and `ShapeEdge` conforms on its own -- each has one
  inherent-implementation for `Shape`, and each compiles alone against a client
  that imports only it. What no program can have is both: 6.7.10.2 selects an
  implementation from the receiver's *type*, and `s.Area` would then have two
  candidates with nothing in the text to choose between them.

  The refusal lands on the second component the translation reads, which is
  where the second implementation is, and the use site then reports that the
  routine it wanted is not implemented -- the cascade, not a second defect.

  This is the claim `tests/dialect/methods_errors.pas` could not make: that one
  holds two implementations for `Point` in **one** component, which the parser
  and Sema see together. Nothing here held the cross-component half until
  ADR-0413. }
program impl_two_modules(output);

import ShapeArea; ShapeEdge; ShapeOwner;

var s: Shape;

begin
  s := NewShape(3);
  writeln(s.Area:1, ' ', s.Perimeter:1)
end.
