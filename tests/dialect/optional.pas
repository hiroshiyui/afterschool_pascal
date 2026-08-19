{ ADR-0123: an optional is a type, `?T`, and `nil` is its only other value.

  Neither standard has one. It is here because a foreign function that answers
  a pointer may answer a null one -- `getenv` of a name that is not set does,
  in the ordinary course of things -- and ADR-0122 refused the whole result
  direction for want of somewhere for null to live.

  What the type buys is stated the other way round: a `T` that is not optional
  can never be absent, so `o^` is the only way to a value and it is checked. }
program optional(output);

type
  Name = string(16);
  OptName = ?Name;
  OptInt = ?integer;
  Point = record x, y: integer end;
  OptPoint = ?Point;
  Row = record key: Name; count: OptInt end;
  { A schema whose body holds an optional (ADR-0039, ADR-0123): the body is
    walked for its names once, and re-resolved for every tuple -- so a denoter
    that nests, as `?T` does and `^T` does not, has to be walked in both
    places or the second production shares the first one's type. }
  Slots(cap: integer) = record
    used: integer;
    { Written out rather than named: a *name* there is an nkNamed denoter and
      the walk never sees a `?` at all, which is precisely the arm at issue. }
    slot: array [1..cap] of ?integer
  end;

var
  n, m: OptName;
  i: OptInt;
  p: OptPoint;
  r: Row;
  table: array [1..4] of OptName;
  small: Slots(2);
  large: Slots(5);
  k: integer;

{ A parameter and a result, so the value travels by address in both
  directions -- an optional is IsMemory, like a record. }
function Lookup(want: integer): OptName;
begin
  if want = 1 then Lookup := 'one'
  else if want = 2 then Lookup := 'two'
  else Lookup := nil
end;

procedure Show(what: string(8); o: OptName);
begin
  write(what, ' = ');
  if o = nil then writeln('(absent)') else writeln(o^)
end;

begin
  { The two values, and the test that tells them apart. }
  i := nil;
  writeln('absent    = ', (i = nil));
  i := 42;
  writeln('present   = ', (i <> nil), ' ', i^:1);

  { `o^` is an ordinary designator: it may be read, and assigned through. }
  i^ := i^ + 1;
  writeln('through   = ', i^:1);

  { A whole-value copy, flag and all -- and the source going absent afterwards
    does not reach the copy. }
  n := 'hello';
  m := n;
  n := nil;
  Show('copy    ', m);
  Show('source  ', n);

  { A record is a value like any other, and an optional of one is a value too:
    the flag sits in front of the whole record. }
  p := nil;
  writeln('point     = ', (p = nil));

  { And an optional *inside* a record, which is where it earns itself: a count
    that has not been taken is not a count of zero. }
  r.key := 'k';
  r.count := nil;
  writeln('untaken   = ', (r.count = nil));
  r.count := 0;
  writeln('taken     = ', (r.count = nil), ' ', r.count^:1);

  { An array of them, so the storage is laid out repeatedly. }
  for k := 1 to 4 do
    if k mod 2 = 1 then table[k] := 'odd' else table[k] := nil;
  for k := 1 to 4 do
    Show('table   ', table[k]);

  Show('found   ', Lookup(1));
  Show('found   ', Lookup(2));
  Show('missing ', Lookup(3));

  { Two productions of one schema, so the optional inside is resolved twice. }
  small.used := 2;
  small.slot[1] := 10;
  small.slot[2] := nil;
  large.used := 5;
  for k := 1 to 5 do
    if k = 3 then large.slot[k] := k * 100 else large.slot[k] := nil;
  writeln('slots      = ', small.slot[1]^:1, ' ', (small.slot[2] = nil),
          ' ', large.slot[3]^:1, ' ', (large.slot[1] = nil))
end.
