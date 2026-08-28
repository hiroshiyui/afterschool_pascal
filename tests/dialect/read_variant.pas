{ ISO/IEC 10206:1991 6.10.2 makes `read` an assignment, so the dialect's
  variant activation applies to its target.

  The clause writes the procedure out: the execution of `read(f, v)` "shall be
  equivalent to begin v := f^; get(f) end". Its NOTE 2 removes any doubt about
  what may stand there -- "the variable-access is not a variable parameter.
  Consequently, it may be a variant-selector or a component of a packed
  structure".

  ADR-0118 makes a write to a field of a variant activate that variant, and
  designatorGuard was set to vgWrite at exactly one construct: the target of an
  assignment-statement. A read is the other one, and it was left as a *read* --
  so this program, which is valid ISO/IEC 10206:1991, stopped at

      runtime error: variant: the tag selects another arm

  under ADR-0118's rule while working under a Pascal without it. That is a
  containment break (ADR-0117), and no case in tests/extended/ could find it
  because none of them reads into a variant -- which is what ADR-0138's sweep
  measures rather than what it can see.

  The guard is cleared per argument and not per statement: `read(a, b)` assigns
  to both, and each is its own designator. }
program ReadVariant(input, output);
type
  Col = (red, green);
  Rec = record
    case k: Col of
      red:   (i: integer);
      green: (gr: integer)
    end;
var r: Rec; other: Rec;
begin
  { the tag names the *other* arm, so a read that did not activate would trap }
  r.k := red;
  read(r.gr);
  writeln('one: tag = ', ord(r.k):1, ', gr = ', r.gr:1);

  { two targets in one statement, each activating its own designator }
  other.k := red;
  read(r.gr, other.gr);
  writeln('two: ', ord(r.k):1, ' ', r.gr:1, ' ', ord(other.k):1, ' ', other.gr:1)
end.
