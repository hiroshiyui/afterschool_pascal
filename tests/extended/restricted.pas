{ ISO/IEC 10206:1991 §6.4.2.5's restricted-type.

    restricted-type = 'restricted' type-name .

  "A restricted-type shall denote a type whose set of states is associated
  one-to-one with the states determined by another type, designated the
  underlying-type." So a restricted type has the underlying type's values and
  the underlying type's representation, and differs only in what a program may
  *do* with one. The NOTE says exactly what that is:

    - assigned to or from a variable of the underlying-type;
    - passed as a value parameter to a formal of the underlying-type;
    - passed as a var parameter to a formal of the same type or the
      underlying-type;
    - returned as a function result.

  "No other operations, such as accessing a component of a restricted-type
  value or performing arithmetic, are possible."

  This compiler makes that sentence true by construction rather than by a list
  of prohibitions: a restricted-type is its own `TypeKind`, so `isArray`,
  `isInteger`, `isOrdinal` and `isStringType` all answer `false` and every
  operation refuses it through the diagnostic it already had.
  `restricted_errors.pas` is that half. Only two predicates see through —
  `isStructured` and `isMemory` — because *how a value travels* is still the
  underlying type's business.

  The standard's own example is what it is for: a module exports the restricted
  name and not the underlying one, so a user of the interface can hold the
  values and pass them on and nothing else. This program is that example
  without the module, which is a separate feature (§6.11). }
program RestrictedTypes(output);
type
  realwidget = record f1: integer; f2: real end;
  widget     = restricted realwidget;

  { The underlying type may be any type, not only a record. }
  count      = integer value 5;
  handle     = restricted count;
  tag        = restricted char;

  { A restricted *variable-string*, which is the one shape that tells
    `isMemory` from `isStructured`: a variable-string is neither an array nor a
    record, so only `isMemory` says it travels by address (ADR-0051). Without
    a program of this shape, a compiler whose `isMemory` did not see through a
    restricted type behaved identically on every other one. }
  label_     = string(12);
  ticket     = restricted label_;

var w, w2: widget; r: realwidget; h: handle; c: char; t: tag; i: integer;
    k: ticket; nm: label_;

{ A function may return a restricted type, and it is written by building the
  *underlying* value and assigning it — §6.4.2.5's own example does this. }
function increment(x: realwidget): widget;
var copy: realwidget;
begin
  copy.f1 := x.f1 + 1;
  copy.f2 := x.f2 + 1.0;
  increment := copy
end;

{ A value parameter of the underlying type accepts a restricted argument. }
procedure show(v: realwidget);
begin writeln(v.f1:1, ' ', v.f2:1:1) end;

{ ...and so does a var parameter, which is the only place the rule is a
  *widening* rather than a compatibility: nothing is converted through a
  reference, because the representation is the same one. }
procedure fill(var v: realwidget);
begin v.f1 := 7; v.f2 := 2.5 end;

{ A var parameter of the restricted type itself, which is the other half of
  the NOTE's third bullet. }
procedure pass(var v: widget);
begin fill(v) end;

{ A *value* parameter of the restricted type itself, and a function returning
  one. These are what ask how a restricted value travels rather than what may
  be done with it, so they are the only programs that can tell `isStructured`
  and `isMemory` from predicates that stop at the kind. Assignment cannot: it
  unwraps to the underlying type before it asks anything. }
procedure takeWidget(v: widget);
var u: realwidget;
begin u := v; writeln('byval  ', u.f1:1, ' ', u.f2:1:1) end;

function makeTicket: ticket;
var u: label_;
begin u := 'made'; makeTicket := u end;

begin
  r.f1 := 1; r.f2 := 1.0;

  { Both directions of assignment. }
  w := r;
  show(w);
  r := w;
  writeln('back   ', r.f1:1);

  { A restricted value assigns to a variable of its own type too — that is
    §6.4.6 a), "the same type", and needs no clause of its own. }
  w2 := w;
  show(w2);

  { A function result. }
  w := increment(r);
  show(w);

  { A var parameter of the underlying type... }
  fill(w);
  show(w);

  { ...and of the restricted type, handed on to one of the underlying type. }
  r.f1 := 0; r.f2 := 0.0;
  w := r;
  pass(w);
  show(w);

  { §6.4.2.5: "The initial state denoted by a restricted-type shall be the
    state associated with the initial state denoted by the type-name of the
    restricted-type." `count` carries `value 5`, so `handle` does — the same
    hand-on §6.4.1 gives a type-name (ADR-0048). }
  i := h;
  writeln('init   ', i:1);

  { A simple underlying type behaves the same way, and its restriction is just
    as complete: `t` may be assigned from a char and read back into one, and
    that is all. }
  c := 'q';
  t := c;
  c := t;
  writeln('char   ', c);

  { The variable-string case, both directions. A restricted variable-string is
    reached through its address like the string it restricts, which is
    `isMemory` and not `isStructured` — and the assignment is the string
    store, so a short value is padded to nothing and its length is its own. }
  nm := 'afterschool';
  k := nm;
  nm := k;
  writeln('string [', nm, '] ', length(nm):1);

  takeWidget(w);
  nm := makeTicket;
  writeln('result [', nm, ']')
end.
