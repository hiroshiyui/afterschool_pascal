{ A schema type whose component contains a variable-string, allocated on the
  heap. ISO/IEC 10206:1991 6.7.5.3's `new(p, d)` produces the type from the
  tuple, and nothing about 6.4.3.3.2's string-type stops it appearing inside
  one -- a string of fixed capacity is a component like any other.

  Sema asks StaticThroughout whether a bound anywhere inside the domain depends
  on a discriminant, and that walk reaches every component. It reached a
  tyString and had no arm for one, so each of the three shapes below stopped
  the *compiler* with "case: no label matches the selector" rather than
  compiling. A string whose capacity is itself a discriminant never gets that
  far: it carries hiDisc and the test above the case answers for it. So a
  tyString reaching the walk has a fixed capacity and is static by
  construction, which is the arm this pins.

  The three shapes are separate because they reach the walk by different
  routes: the array's component, the record's field list, and an array of
  records nesting one inside the other. }
program SchemaStringHeap(output);
type
  { the component *is* the string }
  Names(cap: integer) = array [1..cap] of string(16);
  { the string is a field of a schema record }
  Boxed(cap: integer) = record
    tag: string(8);
    room: array [1..cap] of integer
  end;
  { an array of records, each holding a string -- the shape a keyed container
    wants, and the one that found this }
  Entry = record
    key: string(16);
    val: integer
  end;
  Table(cap: integer) = array [0..cap] of Entry;

var
  ns: ^Names;
  bx: ^Boxed;
  tb: ^Table;
  i, n: integer;

begin
  n := 3;

  new(ns, n);
  ns^[1] := 'alpha';
  ns^[2] := 'beta';
  ns^[3] := 'gamma';
  for i := 1 to n do
    writeln('name ', i:1, ' = ', ns^[i]);
  dispose(ns);

  new(bx, 4);
  bx^.tag := 'boxed';
  for i := 1 to 4 do
    bx^.room[i] := i * 10;
  writeln('tag = ', bx^.tag, ' room4 = ', bx^.room[4]:1);
  dispose(bx);

  { the discriminant is a variable, so the size is not known until run time --
    which is the whole reason the walk happens at all }
  new(tb, n);
  for i := 0 to n do begin
    tb^[i].key := 'k';
    tb^[i].val := i * i
  end;
  tb^[2].key := 'found';
  for i := 0 to n do
    writeln('slot ', i:1, ' ', tb^[i].key, ' ', tb^[i].val:1);
  dispose(tb)
end.
