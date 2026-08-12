{ §6.4.2.5's NOTE: "No other operations, such as accessing a component of a
  restricted-type value or performing arithmetic, are possible."

  Almost none of these refusals is written down anywhere in the compiler. A
  restricted-type is its own `TypeKind`, so `isInteger`, `isOrdinal`,
  `isArray`, `isStringType` and the rest all answer `false`, and each operation
  below refuses it through the diagnostic it already had — naming the type,
  which is what a reader needs. That is the same shape ADR-0044's
  variant-selector and ADR-0046's `new(p)` have: refused by construction.

  Exactly one refusal *is* written down, and it is the comparison. `assignable`
  had to be taught that a restricted type and its underlying-type assign to
  each other (§6.4.2.5's first two sentences), and a comparison asks
  `assignable` — so without a line of its own, `n = 3` would ride in on the
  assignment's permission. }
program RestrictedErrors(output);
type
  rw     = record f1: integer; f2: real end;
  widget = restricted rw;
  ri     = restricted integer;
  ra     = restricted rw;
  { §6.4.2.5: "The bindability denoted by a restricted-type shall be
    nonbindable." }
  rb     = bindable restricted rw;
  { Every type has an underlying-type — its own, when it is not restricted —
    so a second wrapper over one underlying-type would have nothing to tell it
    from the first. }
  rr     = restricted widget;
  { 6.4.2.5's NOTE leaves a file no permitted operation at all — a file is
    never assigned, never a value parameter and never a function result — so a
    restricted file would be a variable nothing could do anything with. }
  rf     = restricted text;
var w: widget; n: ri; i: integer; r: rw; q: ra;

{ A var parameter of the *underlying* type accepts the restricted one
  (§6.4.2.5's NOTE) — but not the other way round, or the restriction would be
  escapable by declaring one parameter. }
procedure needsRestricted(var v: widget); begin v := v end;

{ ADR-0052 refuses a variable-string *value* parameter: it would have to be
  converted at the call and there is nowhere to build the conversion. A
  restricted string needs exactly the same conversion, so it is refused the
  same way — a restricted type does not launder a rule about how a value is
  passed. The check asks the underlying type, and this is the program that
  says so. }
type sname = string(12);
     stag  = restricted sname;
procedure takeTag(s: stag); begin writeln(s) end;

begin
  { Arithmetic. }
  i := n + 1;

  { A component of the value. }
  writeln(w.f1:1);

  { Comparison — the one that needs a rule, because assignment has one. }
  if n = 3 then writeln('eq');

  { Writing it: §6.10.3.1 lists what `write` accepts and this is not on it. }
  writeln(n:1);

  { An ordinal context: a case selector, a for control variable, `ord`. }
  case n of 1: writeln('one') end;
  i := ord(n);

  { Two restrictions of one underlying type are still two types (ADR-0017),
    so neither assigns to the other — only each to `rw`. }
  q := w;

  { And the widening goes one way. }
  needsRestricted(r);

  { What is legal, so the file ends by proving the refusals above are about
    the operations and not about the type being unusable. }
  r.f1 := 1; r.f2 := 2.0;
  w := r;
  r := w;
  writeln(r.f1:1)
end.
