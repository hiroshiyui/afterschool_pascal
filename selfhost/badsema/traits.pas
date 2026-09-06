{ AP 6.4's trait-declaration, AP 6.7's implementation-declaration and AP
  6.7.3.10.5's trait bound (ADR-0338, ADR-0339, ADR-0340). Sema accumulates, so
  one file carries the set.

  The first of these was `selfhost/badparse/type-param-category.pas` until this
  change, and it moved rather than being rewritten. ADR-0266 could put that
  message in the *parser* because the set of categories was closed: four
  spellings, matched by text, with no lookup needed. A trait is spellable in
  the same position and only a lookup can tell one from a misspelling, so the
  decision is Sema's now and the message names a trait among the alternatives.
  What the parser kept is the commitment to the shape -- an identifier followed
  by the word-symbol `type` -- which is the half that made a message about a
  category writable instead of one about a semicolon that never came. }
program p(output);
type Point = record x: integer end;
     Digit = 1..9;
     Other = record y: integer end;
     Third = record z: integer end;

trait Ord;
  function Compare(a: Self; b: Self): integer;
end;

impl Ord for Point;
  function Compare;
  begin Compare := a.x - b.x end;
end;

{ AP 6.4: `Self` is admitted as a whole parameter-form or result-type and
  refused inside one. 6.4.1 gives each denoter that is not a type-name its own
  type object, so `array of Self` in the trait and `array of Point` in an
  implementation would be two objects, and congruity -- which compares
  identity -- would refuse every implementation.

  Reported at the *trait* and not at the implementation: the mistake is in the
  trait, and left to the implementation the message arrives once per one, in a
  source whose author wrote nothing wrong. This trait is deliberately left
  unimplemented, because a heading is re-parsed per implementation and an
  error in one is therefore reported again for each -- which is a wart worth
  knowing about and is why the case that shows the message shows it once. }
trait Ranked;
  procedure Rank(protected var xs: array of Self);
end;

{ A trait that is not one. }
impl Point for Other;
  function Compare;
  begin Compare := 0 end;
end;

{ A trait nobody declared. }
impl Sortable for Other;
  function Compare;
  begin Compare := 0 end;
end;

{ AP 6.7: a name after `for` that denotes no type. }
impl Ord for Missing;
  function Compare;
  begin Compare := 0 end;
end;

{ ADR-0018 and the Base() lookup: a subrange selects its host's
  implementation, so one written for it could never be chosen. }
impl Ord for Digit;
  function Compare;
  begin Compare := 0 end;
end;

{ One implementation of one trait for one type. }
impl Ord for Point;
  function Compare;
  begin Compare := 0 end;
end;

{ A routine the trait does not declare. }
impl Ord for Third;
  function Compare;
  begin Compare := 0 end;
  function Nearest: integer;
  begin Nearest := 0 end;
end;

{ The other three places `Self` can be written *inside* a denoter (ADR-0339,
  and the fix ADR-0340 records): among a schema's actual discriminants, where
  the parser makes it an nkVar and not an nkNamed because a type argument and
  an ordinal one are spelled alike; as the component of a conformant array
  schema; and inside a result type. `Box(Self, 3)` slipped through once and
  produced an implementation nothing could select. }
type Box(K: integer; n: integer) = record a: array [1..n] of K end;

trait Deep;
  function A(b: Box(Self, 3)): integer;
  function C(d: array [lo..hi: integer] of Self): integer;
  function D(e: Self): Box(Self, 3);
end;

{ AP 6.7: an implementation writes each routine's name alone, the trait having
  given the heading. A second copy is one that can disagree with the first,
  and refusing it is what makes congruity a question that cannot arise. }
impl Ord for Other;
  function Compare(a: Other; b: Other): integer;
  begin Compare := a.y - b.y end;
end;

{ An implementation defines every routine the trait declares, or it is not
  one -- a client that finds the impl and not the routine would otherwise fall
  to `unknown function` with the impl in plain sight. }
trait Two;
  function F(a: Self): integer;
  function G(a: Self): integer;
end;

impl Two for Point;
  function F;
  begin F := 1 end;
end;

{ An implementation is selected from wherever its type is in scope, so one
  nested in a procedure could be chosen from outside the procedure, where its
  own scope does not exist; it printed 14 where 106 was right before this was
  refused (ADR-0340). }
procedure Inner;
  impl Two for integer;
    function F;
    begin F := 1 end;
    function G;
    begin G := 2 end;
  end;
begin end;

{ AP 6.7.3.10.5: a spelling in the category position that is neither one of
  the four nor a trait. }
function Sum(Elem: hashable type; a, b: Elem): Elem;
begin Sum := a end;

{ A trait *procedure* is dispatched where a function is called (ADR-0340
  dispatches by the first actual in expression position and nowhere else),
  and is then refused for the same reason any procedure is. }
trait Shown;
  procedure Show(a: Self);
end;

impl Shown for Point;
  procedure Show;
  begin writeln(a.x:1) end;
end;

var u, v: Point; s: Other;
begin
  u.x := 1; v.x := 2; s.y := 3;
  writeln(Show(u):1);
  { The bound is checked at the activation, which is the whole of what a
    constraint buys. }
  writeln(Compare(u, v):1);
  writeln(Sum(s, s).y:1)
end.
