{ ISO/IEC 10206:1991 6.4.2.4 writes `subrange-bound = expression`, and 6.2.3.8 b)
  evaluates one "closest-contained by ... the block" at the block's
  commencement. ADR-0113 took that for an array's index-type and ADR-0127 for a
  type-definition's; this is the position both of them left refused, and
  ADR-0133 is what admits it: a subrange written as a variable's own type, as a
  type-definition and as an array's *component*.

  What made it the last one is that a bound in an index-type is read by the
  subscript check, out of the descriptor, and a bound anywhere else is read by
  the range check at a store -- which compared against the two numbers on the
  type, and for such a subrange those are placeholders. The check now reads the
  descriptor by the call the subscript check already made.

  A subrange needs nothing of the sizing the clause is otherwise about: its
  storage is its host's whatever its bounds are. So every host is here -- an
  integer, a char and an enumeration -- and `inner` reads the descriptor of an
  enclosing activation by the static chain, which is the walk any enclosing
  variable makes. }
program DynBoundsSubrange(output);
type colour = (red, green, blue, violet);
procedure p(m: integer; c: char; e: colour);
type t = 1..m;                           { a bare subrange, as a type }
var x: t;                                { and a variable of it }
    y: 1..m;                             { a bare subrange, as a variable }
    ch: 'a'..c;                          { a char host }
    en: red..e;                          { an enumerated host }
    a: array [1..m] of 1..m;             { a component, not an index-type }
    b: array [1..2] of 1..m;             { a component whose index is static }
    n: array [1..m, 1..m] of 1..m;       { both, at two dimensions }
    i: integer;
    { 6.4.4 makes a pointer's domain a type *identifier*, so this is the one
      way a heap variable can have such a type -- and it needs no tuple in
      front of it, `new` building one only where the extent is dynamic. The
      bounds stay the block's, which is what the store is checked against. }
    h: ^t;
    { A record is no kind of block, so a bound written inside one is still
      closest-contained by this block and 6.2.3.8 b) reaches it (ADR-0134).
      What makes a *subrange* field work where an array field does not is that
      it sizes nothing: `rec` is eight bytes whatever m is, so `g` sits at an
      offset this compiler can compute. }
    rec: record f: 1..m; g: integer end;
    { And a file's component, for the same reason: the runtime is told one
      component size when the file is prepared, and a subrange's is its
      host's. }
    fl: file of 1..m;
  { The bounds belong to the activation of p that is running, so a nested
    procedure reaches them the way it reaches any other variable of it. }
  procedure inner;
  begin
    y := m;
    writeln('inner ', y:1)
  end;
begin
  x := m; y := 2; ch := 'b'; en := green;
  writeln(x:1, ' ', y:1, ' ', ch, ' ', ord(en):1);
  for i := 1 to m do a[i] := i;
  b[2] := m;
  n[m, m] := m;
  writeln(a[1]:1, a[m]:1, ' ', b[2]:1, ' ', n[m, m]:1);
  { 6.7.1 treats a factor of a subrange type as being of the type it is a
    subrange of, so succ and pred look at the *host's* ends and not at these
    -- which is what keeps 1 and 3 from being errors here (6.6.6.4). }
  x := succ(1);
  writeln(x:1);
  new(h);
  h^ := m;
  writeln('heap ', h^:1);
  dispose(h);
  rec.f := m; rec.g := 8;
  writeln('field ', rec.f:1, rec.g:1);
  rewrite(fl); fl^ := 2; put(fl);
  reset(fl);
  writeln('component ', fl^:1);
  inner
end;
begin p(3, 'c', blue) end.
