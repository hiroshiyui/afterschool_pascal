{ A constant may be `nil`.

  ISO/IEC 10206:1991 §6.7.1 makes `nil` an unsigned-constant, so it is a
  primary and therefore an expression; §6.8.2 makes a constant-expression any
  expression that is nonvarying, and `nil` reads nothing at all. So
  `const q = nil` is a program the standard has. ISO 7185 §6.3's `constant` is
  a signed literal or the name of another constant and has no `nil` in it,
  which is why the refusal was right in one language and wrong in the other —
  `tests/constexpr_iso_fold.pas` is that half.

  §6.4.4's NOTE 2 is what makes the feature one line: "The token nil does not
  have a single type, but assumes a suitable pointer-type to satisfy the
  assignment-compatibility rules". That is ADR-0019's nil-type, assignable to
  every pointer-type and with nothing assignable to it, so the constant needs
  no type of its own and one `q` serves `pi` and `pc` alike. Nothing outside
  the folder had to learn that a constant can be a pointer.

  What the last two definitions pin is the combination rather than either
  half. §6.8.7's structured-value-constructor keeps the node the program wrote
  (ADR-0069), so a nil component was already accepted — but §6.8.8's
  constant-access then *selects* that component, and selecting it is a fold of
  the `nil` node. `arr[2]` is the program that could not have worked before. }
program ConstNil(output);

type
  pi   = ^integer;
  pc   = ^char;
  link = record next: pi; n: integer end;
  parr = array [1..2] of pi;

const
  q = nil;
  { §6.3.2's `const b = a` shape: the folder hands on one node, so the two
    names denote one value rather than a copy of it. }
  r = q;
  head = link[next: nil; n: 7];
  arr  = parr[1..2: q];

var
  a: pi;
  c: pc;
  { §6.6's initial state is a nonvarying expression too, so it may be the
    constant. }
  d: pc value r;
  v: link;
  t: parr;

{ A value parameter is an assignment (§6.6.3.2), so the nil-type reaches it by
  the rule it already had. }
procedure takes(p: pi);
begin
  writeln('param nil is ', p = nil)
end;

begin
  a := q;
  c := r;
  writeln('two types: ', a = nil, ' ', c = nil, ' ', d = nil);
  writeln('one value: ', q = r);
  takes(q);
  v := head;
  t := arr;
  writeln('in a record: ', v.next = nil, ' ', head.n:1);
  writeln('in an array: ', t[1] = nil, ' ', arr[2] = q)
end.
