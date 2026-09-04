{ AP 6.4.14.7: what may not be released while a borrow of what it owns is open.

  `tests/dialect/owned_borrow.pas` is the half that works -- a `var` parameter
  bound to `o^` is a second name for what `o` owns, for the duration of the
  call, and it cannot escape one (ADR-0201). That record's safety argument is
  *the borrow cannot outlive the call*, and it is one of two halves: the other
  is that what is borrowed must outlive the borrow, and AP 6.4.14.3 gives a
  callee three ways to end it early -- `dispose`, `new`, and an assignment.

  Until this file, every one of them compiled and ran. `P(q, q^)` with
  `dispose(o)` in the body wrote 42 through disposed storage and exited 0,
  and made observable by allocating again in between, the write landed in an
  unrelated live variable. It is ADR-0201's own probe -- two `var` parameters
  bound to one variable, pronounced safe -- with `dispose` where that record
  wrote `take`.

  Two forms are detected and each is one activation's own business: the two
  actual-parameters of one call, and a `with` whose element was reached
  through the pointer. What is *not* detected is a release reached through a
  further activation -- the callee naming the owner as a non-local, or being
  handed it by something else -- which is Annex C.12 and needs a summary over
  the whole program (ADR-0317).

  The double-release shape is deliberately absent: `dispose` empties the
  variable it was given, so `P(q, q)` disposing both parameters meets the nil
  trap of Annex D and is already answered. A borrow is the second name that is
  *not* a variable, and nothing empties it -- which is the whole of why this
  clause is about borrows. }
program owned_borrow_errors(output);

type Own = owned ^Node;
     Node = record v: integer; other: Own; plain: ^Node;
                    kids: array [1..2] of Own end;
     Box = record p: Own; q: Own end;

var o: Own; r: Box;

{ The two arguments this clause is about: one releases, the other names what
  it owns. }
procedure P(var a: Own; var n: Node);
begin n.v := 1 end;

{ The same pair the other way round. An owner is as dangerous after its borrow
  as before it. }
procedure Q(var n: Node; var a: Own);
begin n.v := 1 end;

{ A whole record holding an owned pointer is an owner too: the callee reaches
  `b.p` and releases through it. }
procedure Thru(var b: Box; var n: Node);
begin n.v := 1 end;

{ Neither argument can release: two borrows of one variable are safe, and this
  one must go on compiling. }
procedure Two(var m, n: Node);
begin m.v := n.v end;

{ A value parameter is copied where the call is made, so nothing it names can
  be released under it. Also must go on compiling. }
procedure ByValue(var a: Own; n: integer);
begin a^.v := n end;

begin
  new(o);
  new(r.p);
  new(r.q);

  { the call form, both orders }
  P(o, o^);
  Q(o^, o);

  { through a container: the entire-variable is the unit, as 6.9.4 h) makes it }
  Thru(r, r.p^);

  { and through a chain of owned dereferences }
  new(o^.other);
  P(o, o^.other^);

  { and through a subscript, which stays inside the same entire-variable }
  new(o^.kids[2]);
  P(o, o^.kids[2]^);

  { the with form: the binding is open for the whole body and nothing empties
    it, so all three release points are refused inside it }
  with o^ do begin
    dispose(o);
    new(o);
    o := take(r.p)
  end;

  { and reached through a chain, where the with-element is deeper than the
    pointer being released }
  with o^.other^ do
    dispose(o);

  { What is still admitted, and must be. Two borrows and no owner: neither
    argument can release anything the other names, which is why the owner side
    of the rule asks for an entire-variable. }
  Two(o^, o^);
  ByValue(o, o^.v);

  { a `with` on something that owns nothing releases what it likes }
  with r do
    dispose(p);

  { The path leaves the owned variable at an *ordinary* dereference, so what it
    names is storage `o` never held and releasing `o` frees none of it. Must go
    on compiling, and it is why the walk answers nil at a dereference that is
    not of an owned pointer rather than carrying on to the root. }
  new(o^.plain);
  P(o, o^.plain^);
  dispose(o^.plain)
end.
